import { Controller } from "@hotwired/stimulus"

// Monitor de áudio ao vivo da simulação (somente escuta). O navegador NÃO fala: isto não é
// browser_voice. O áudio nunca passa pelo Rails — o Rails só emite um ticket curto e o
// navegador abre um WebSocket direto na FastAPI com esse ticket.
//
// Fluxo:
//   clique "Ativar áudio"  → cria/retoma AudioContext (exige gesto do usuário, por autoplay)
//                          → GET ticket no Rails → abre WSS → recebe PCM16 8 kHz por participante
//                          → agenda a reprodução com um jitter buffer pequeno e pan sutil.
//
// Regras: se o áudio cair, a simulação continua (o monitor é observabilidade). Ao terminar a
// simulação ou sair da página, fecha só o monitor; jamais cancela a execução.
const SAMPLE_RATE = 8000
// Jitter buffer: começa a tocar com ~120 ms acumulados e mantém a fila curta para não atrasar.
const START_DELAY_SECONDS = 0.12
const MAX_BUFFER_AHEAD_SECONDS = 0.6
// Pan sutil: agente levemente à esquerda, fornecedor levemente à direita.
const AGENT_PAN = -0.35
const COUNTERPART_PAN = 0.35
const SOURCE_AGENT = 0x00
const SOURCE_COUNTERPART = 0x01

export default class extends Controller {
  static targets = ["activate", "live", "status", "mute"]
  static values = {
    ticketUrl: String,
    active: Boolean // a simulação está em execução? (controla se oferecemos o monitor)
  }

  connect() {
    this.audioContext = null
    this.socket = null
    this.muted = false
    this.manualStop = false
    this.reconnectAttempts = 0
    this.reconnectTimer = null
    this.nextStartTime = { [SOURCE_AGENT]: 0, [SOURCE_COUNTERPART]: 0 }

    // Fecha o monitor se a aba for descarregada (sem cancelar a simulação).
    this.onPageHide = () => this.teardownAudio()
    window.addEventListener("pagehide", this.onPageHide)

    // Sem suporte a Web Audio ou simulação já encerrada: não oferece o controle.
    if (!this.activeValue || !this.webAudioSupported()) {
      this.element.hidden = true
    }
  }

  disconnect() {
    window.removeEventListener("pagehide", this.onPageHide)
    this.teardownAudio()
  }

  webAudioSupported() {
    return typeof (window.AudioContext || window.webkitAudioContext) === "function"
  }

  // --- ativação (precisa de gesto do usuário) ---
  async activate() {
    if (this.audioContext) return
    this.manualStop = false
    this.setStatus("connecting")

    try {
      // Criar/retomar o AudioContext DENTRO do handler do clique satisfaz a política de autoplay.
      const AudioContextClass = window.AudioContext || window.webkitAudioContext
      this.audioContext = new AudioContextClass()
      if (this.audioContext.state === "suspended") await this.audioContext.resume()

      this.masterGain = this.audioContext.createGain()
      this.masterGain.gain.value = this.muted ? 0 : 1
      this.masterGain.connect(this.audioContext.destination)

      await this.openSocket()
    } catch (error) {
      console.error("[simulation-audio] falha ao ativar áudio", error)
      this.setStatus("error")
      this.teardownAudio({ keepUi: true })
    }
  }

  async openSocket() {
    const response = await fetch(this.ticketUrlValue, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      }
    })
    if (!response.ok) throw new Error(`ticket HTTP ${response.status}`)
    const { url, ticket } = await response.json()
    if (!url || !ticket) throw new Error("ticket incompleto")

    // O Rails devolve a URL WSS da API e o ticket curto separadamente; o ticket vai na query.
    const socketUrl = new URL(url)
    socketUrl.searchParams.set("ticket", ticket)

    const socket = new WebSocket(socketUrl.toString())
    socket.binaryType = "arraybuffer"
    this.socket = socket

    socket.addEventListener("open", () => {
      this.reconnectAttempts = 0
      this.showLive()
    })
    socket.addEventListener("message", (event) => this.handleFrame(event.data))
    socket.addEventListener("close", () => this.handleSocketClosed())
    socket.addEventListener("error", () => socket.close())
  }

  // --- recepção e reprodução ---
  handleFrame(data) {
    if (!this.audioContext || !(data instanceof ArrayBuffer) || data.byteLength < 2) return
    const bytes = new Uint8Array(data)
    const source = bytes[0]
    const pcm = this.decodePcm16(bytes.subarray(1))
    if (pcm.length === 0) return
    this.schedule(source, pcm)
  }

  decodePcm16(bytes) {
    // PCM16 little-endian → Float32 [-1, 1]. Ignora byte ímpar solto (não deve ocorrer).
    const samples = Math.floor(bytes.length / 2)
    const view = new DataView(bytes.buffer, bytes.byteOffset, samples * 2)
    const out = new Float32Array(samples)
    for (let i = 0; i < samples; i += 1) {
      out[i] = view.getInt16(i * 2, true) / 32768
    }
    return out
  }

  schedule(source, pcm) {
    const context = this.audioContext
    const buffer = context.createBuffer(1, pcm.length, SAMPLE_RATE)
    buffer.copyToChannel(pcm, 0)

    const node = context.createBufferSource()
    node.buffer = buffer

    const panner = context.createStereoPanner()
    panner.pan.value = source === SOURCE_AGENT ? AGENT_PAN : COUNTERPART_PAN
    node.connect(panner)
    panner.connect(this.masterGain)

    // Jitter buffer por participante: mantém a fila entre START_DELAY e MAX_BUFFER_AHEAD.
    const now = context.currentTime
    let startAt = this.nextStartTime[source]
    if (startAt < now + START_DELAY_SECONDS) {
      startAt = now + START_DELAY_SECONDS
    } else if (startAt > now + MAX_BUFFER_AHEAD_SECONDS) {
      // Fila longa demais (cliente ficou atrás): corta para não acumular atraso.
      startAt = now + START_DELAY_SECONDS
    }
    node.start(startAt)
    this.nextStartTime[source] = startAt + buffer.duration
  }

  // --- reconexão ---
  handleSocketClosed() {
    this.socket = null
    if (this.manualStop || !this.audioContext) return
    // Reconecta com backoff curto; o monitor é opcional e nunca trava a página.
    if (this.reconnectAttempts >= 5) {
      this.setStatus("unavailable")
      return
    }
    this.reconnectAttempts += 1
    this.setStatus("reconnecting")
    const delay = Math.min(4000, 500 * 2 ** (this.reconnectAttempts - 1))
    this.reconnectTimer = window.setTimeout(() => {
      this.openSocket().catch(() => this.handleSocketClosed())
    }, delay)
  }

  // --- mute ---
  toggleMute() {
    this.muted = !this.muted
    if (this.masterGain && this.audioContext) {
      // Rampa curta evita clique ao silenciar.
      this.masterGain.gain.setTargetAtTime(this.muted ? 0 : 1, this.audioContext.currentTime, 0.02)
    }
    if (this.hasMuteTarget) {
      this.muteTarget.setAttribute("aria-pressed", String(this.muted))
      this.muteTarget.textContent = this.muted
        ? this.muteTarget.dataset.labelUnmute
        : this.muteTarget.dataset.labelMute
    }
  }

  // --- encerramento (chamado pelo simulation-live quando a execução termina) ---
  stop() {
    this.teardownAudio()
  }

  teardownAudio({ keepUi = false } = {}) {
    this.manualStop = true
    window.clearTimeout(this.reconnectTimer)
    if (this.socket) {
      try { this.socket.close() } catch { /* já fechado */ }
      this.socket = null
    }
    if (this.audioContext) {
      this.audioContext.close().catch(() => {})
      this.audioContext = null
      this.masterGain = null
    }
    this.nextStartTime = { [SOURCE_AGENT]: 0, [SOURCE_COUNTERPART]: 0 }
    if (!keepUi) this.showIdle()
  }

  // --- UI ---
  showLive() {
    if (this.hasActivateTarget) this.activateTarget.hidden = true
    if (this.hasLiveTarget) this.liveTarget.hidden = false
    this.setStatus("live")
  }

  showIdle() {
    if (this.hasActivateTarget) this.activateTarget.hidden = false
    if (this.hasLiveTarget) this.liveTarget.hidden = true
    this.setStatus("idle")
  }

  setStatus(state) {
    this.element.dataset.audioState = state
    if (this.hasStatusTarget) {
      const label = this.statusTarget.dataset[`label${state.charAt(0).toUpperCase()}${state.slice(1)}`]
      if (label) this.statusTarget.textContent = label
    }
  }
}
