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
// Alvo da fila. A linha pode produzir mais rápido que o relógio de áudio do navegador (relógio
// do WSL adiantado, rajadas de rede). Acima do alvo, só janelas em silêncio digital nos dois
// lados deixam de ser agendadas: fala nunca é descartada para reposicionar a timeline.
const MAX_BUFFER_AHEAD_SECONDS = 0.6
// Pan sutil: agente levemente à esquerda, fornecedor levemente à direita.
const AGENT_PAN = -0.35
const COUNTERPART_PAN = 0.35
const SOURCE_AGENT = 0x00
const SOURCE_COUNTERPART = 0x01
const owners = new WeakMap()
let nextNodeId = 0
const originName = (source) => (source === SOURCE_AGENT ? "agent" : "counterpart")
// Padding da linha virtual (µ-law de silêncio) chega como PCM exatamente zero.
const isDigitalSilence = (pcm) => pcm.every((sample) => sample === 0)

export default class extends Controller {
  static targets = ["activate", "live", "status", "mute"]
  static values = {
    ticketUrl: String,
    debug: Boolean,
    active: Boolean // a simulação está em execução? (controla se oferecemos o monitor)
  }

  connect() {
    if (this.connected) return
    owners.get(this.element)?.disconnect()
    owners.set(this.element, this)
    this.connected = true
    this.connectionVersion = (this.connectionVersion || 0) + 1
    this.scheduledNodes = { [SOURCE_AGENT]: new Set(), [SOURCE_COUNTERPART]: new Set() }
    this.audioContext = null
    this.socket = null
    this.muted = false
    this.manualStop = false
    this.reconnectAttempts = 0
    this.reconnectTimer = null
    this.nextStartTime = { [SOURCE_AGENT]: 0, [SOURCE_COUNTERPART]: 0 }
    this.receivedSequence = { [SOURCE_AGENT]: 0, [SOURCE_COUNTERPART]: 0 }
    this.pendingChunk = null

    // Fecha o monitor se a aba for descarregada (sem cancelar a simulação).
    this.onPageHide = () => this.teardownAudio()
    window.addEventListener("pagehide", this.onPageHide)

    // Sem suporte a Web Audio ou simulação já encerrada: não oferece o controle.
    if (!this.activeValue || !this.webAudioSupported()) {
      this.element.hidden = true
    }
  }

  disconnect() {
    this.connected = false
    if (owners.get(this.element) === this) owners.delete(this.element)
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
    let context

    try {
      // Criar/retomar o AudioContext DENTRO do handler do clique satisfaz a política de autoplay.
      const AudioContextClass = window.AudioContext || window.webkitAudioContext
      context = new AudioContextClass()
      this.audioContext = context
      if (context.state === "suspended") await context.resume()
      if (this.audioContext !== context || this.manualStop) return

      this.masterGain = this.audioContext.createGain()
      this.masterGain.gain.value = this.muted ? 0 : 1
      this.masterGain.connect(this.audioContext.destination)

      await this.openSocket()
    } catch (error) {
      if (context && this.audioContext !== context) return
      console.error("[simulation-audio] falha ao ativar áudio", error)
      this.setStatus("error")
      this.teardownAudio({ keepUi: true })
    }
  }

  async openSocket() {
    const context = this.audioContext
    if (!context || this.manualStop) return
    const version = ++this.connectionVersion
    this.retireSocket()
    this.stopScheduledAudio("reconnect")
    // A sequência local é por conexão: o par (agente, fornecedor) de cada janela fica alinhado.
    this.receivedSequence = { [SOURCE_AGENT]: 0, [SOURCE_COUNTERPART]: 0 }
    window.clearTimeout(this.reconnectTimer)
    this.reconnectTimer = null
    const current = () => this.audioContext === context && this.connectionVersion === version && !this.manualStop
    try {
      const response = await fetch(this.ticketUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })
      if (!current()) return
      if (!response.ok) throw new Error(`ticket HTTP ${response.status}`)
      const { url, ticket } = await response.json()
      if (!current()) return
      if (!url || !ticket) throw new Error("ticket incompleto")
      const socketUrl = new URL(url)
      socketUrl.searchParams.set("ticket", ticket)
      const socket = new WebSocket(socketUrl.toString())
      socket.binaryType = "arraybuffer"
      this.socket = socket
      const guard = (callback) => (event) => {
        if (current() && this.socket === socket) callback(event)
      }
      this.socketHandlers = {
        open: guard(() => { this.reconnectAttempts = 0; this.showLive() }),
        message: guard((event) => this.handleFrame(event.data)),
        close: guard(() => this.handleSocketClosed()),
        error: guard(() => socket.close())
      }
      for (const [name, handler] of Object.entries(this.socketHandlers)) socket.addEventListener(name, handler)
    } catch (error) {
      if (current()) throw error
    }
  }

  retireSocket() {
    const socket = this.socket
    this.socket = null
    if (!socket) return
    for (const [name, handler] of Object.entries(this.socketHandlers || {})) socket.removeEventListener(name, handler)
    this.socketHandlers = null
    try { socket.close() } catch { /* já fechado */ }
  }

  // --- recepção e reprodução ---
  handleFrame(data) {
    if (!this.audioContext || !(data instanceof ArrayBuffer) || data.byteLength < 2) return
    const bytes = new Uint8Array(data)
    const source = bytes[0]
    if (source !== SOURCE_AGENT && source !== SOURCE_COUNTERPART) return
    const pcm = this.decodePcm16(bytes.subarray(1))
    if (pcm.length === 0) return
    const chunk = { source, pcm, sequence: ++this.receivedSequence[source] }
    this.traceAudio("received", { origin: originName(source), chunk_sequence: chunk.sequence, duration: pcm.length / SAMPLE_RATE })
    // A FastAPI envia cada janela de 100 ms da linha como um par (agente, fornecedor), nessa
    // ordem. O par é agendado na mesma posição para que os dois lados nunca se desloquem.
    const pending = this.pendingChunk
    this.pendingChunk = null
    if (pending && source === SOURCE_COUNTERPART && pending.sequence === chunk.sequence) {
      this.scheduleWindow([pending, chunk])
      return
    }
    if (pending) this.scheduleWindow([pending])
    if (source === SOURCE_AGENT) this.pendingChunk = chunk
    else this.scheduleWindow([chunk])
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

  // Todo chunk recebido toca exatamente uma vez, em ordem, ou é descartado explicitamente
  // (reconexão/fim do monitor). Acima do alvo, só uma janela silenciosa nos dois lados é pulada;
  // nenhum node já agendado é parado para recuar a timeline.
  scheduleWindow(chunks) {
    const now = this.audioContext.currentTime
    const timeline = Math.max(...chunks.map(({ source }) => this.nextStartTime[source]))
    if (chunks.length === 2 && timeline > now + MAX_BUFFER_AHEAD_SECONDS && chunks.every(({ pcm }) => isDigitalSilence(pcm))) {
      for (const { source, sequence } of chunks) {
        this.traceAudio("silence-trimmed", { origin: originName(source), chunk_sequence: sequence, currentTime: now, nextStartTime: timeline })
      }
      return
    }
    const startAt = Math.max(timeline, now + START_DELAY_SECONDS)
    for (const chunk of chunks) this.schedule(chunk, startAt)
  }

  schedule({ source, pcm, sequence }, windowStart) {
    const context = this.audioContext
    const buffer = context.createBuffer(1, pcm.length, SAMPLE_RATE)
    buffer.copyToChannel(pcm, 0)

    const node = context.createBufferSource()
    node.buffer = buffer

    const panner = context.createStereoPanner()
    panner.pan.value = source === SOURCE_AGENT ? AGENT_PAN : COUNTERPART_PAN
    node.connect(panner)
    panner.connect(this.masterGain)

    const now = context.currentTime
    const nextStartTime = this.nextStartTime[source]
    let startAt = windowStart
    const records = this.scheduledNodes[source]
    const previousEnd = Math.max(now, ...Array.from(records, (record) => record.end))
    if (startAt < previousEnd) {
      this.traceAudio("overlap-prevented", { origin: originName(source), chunk_sequence: sequence, scheduled_start: startAt, previous_end: previousEnd })
      startAt = previousEnd
    }
    const record = { node, panner, start: startAt, end: startAt + buffer.duration, id: ++nextNodeId, sequence }
    const release = () => {
      records.delete(record)
      node.disconnect()
      panner.disconnect()
    }
    node.onended = release
    records.add(record)
    node.start(startAt)
    this.nextStartTime[source] = record.end
    this.traceAudio("scheduled", {
      origin: originName(source), node_id: record.id, chunk_sequence: sequence,
      scheduled_start: startAt, duration: buffer.duration, scheduled_end: record.end,
      currentTime: now, nextStartTime, previous_end: previousEnd
    })
  }

  // Descarte explícito (reconexão, socket encerrado, fim do monitor), sempre com o motivo.
  stopScheduledAudio(reason) {
    const now = this.audioContext?.currentTime
    if (this.pendingChunk) {
      this.traceAudio("discarded", { origin: originName(this.pendingChunk.source), chunk_sequence: this.pendingChunk.sequence, stop_reason: reason })
      this.pendingChunk = null
    }
    for (const origin of [SOURCE_AGENT, SOURCE_COUNTERPART]) {
      for (const record of this.scheduledNodes?.[origin] || []) {
        record.node.onended = null
        try { record.node.stop() } catch { /* já encerrado */ }
        record.node.disconnect()
        record.panner.disconnect()
        this.traceAudio("stopped", {
          origin: originName(origin), node_id: record.id, chunk_sequence: record.sequence,
          scheduled_start: record.start, scheduled_end: record.end, actual_stop_time: now, stop_reason: reason,
          state_before_stop: now < record.start ? "future" : now < record.end ? "playing" : "ended"
        })
      }
      this.scheduledNodes?.[origin]?.clear()
      this.nextStartTime[origin] = 0
    }
  }

  traceAudio(name, detail) {
    if (this.debugValue) this.dispatch(name, { detail })
  }

  // --- reconexão ---
  handleSocketClosed() {
    this.retireSocket()
    this.stopScheduledAudio("socket_closed")
    if (this.manualStop || !this.audioContext || this.reconnectTimer !== null) return
    // Reconecta com backoff curto; o monitor é opcional e nunca trava a página.
    if (this.reconnectAttempts >= 5) {
      this.setStatus("unavailable")
      return
    }
    this.reconnectAttempts += 1
    this.setStatus("reconnecting")
    const delay = Math.min(4000, 500 * 2 ** (this.reconnectAttempts - 1))
    this.reconnectTimer = window.setTimeout(() => {
      this.reconnectTimer = null
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
    this.connectionVersion += 1
    window.clearTimeout(this.reconnectTimer)
    this.reconnectTimer = null
    this.retireSocket()
    this.stopScheduledAudio("teardown")
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
