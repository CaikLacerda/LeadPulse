import { Controller } from "@hotwired/stimulus"

const STATUS_BADGES = {
  queued: ["warning", "fa-clock"],
  running: ["info", "fa-circle-notch fa-spin"],
  completed: ["success", "fa-circle-check"],
  failed: ["danger", "fa-circle-xmark"],
  cancelled: ["neutral", "fa-circle-minus"],
  interrupted: ["warning", "fa-circle-exclamation"]
}

// Tela ao vivo do Ambiente de Simulação. O navegador nunca fala com a FastAPI: faz polling
// no endpoint do Rails (events), que repassa à API. A cada ciclo pede os eventos novos a
// partir de next_after, aplica-os (estado dos agentes, nível de voz, transcript) e, ao
// detectar o fim, troca a tela pelo relatório que o próprio polling trouxe.
//
// Eventos consumidos (contrato da API): status, participant_state, audio_levels, turn, error.
// Não há "campos coletados ao vivo": o resultado só existe no relatório final.
const STATE_LABELS = {
  listening: "listening",
  thinking: "thinking",
  speaking: "speaking"
}

export default class extends Controller {
  static targets = [
    "statusBadge", "clock", "turnCount",
    "agentCard", "counterpartCard", "agentState", "counterpartState",
    "waveAgent", "waveCounterpart",
    "transcript", "transcriptEmpty",
    "liveActions", "report", "arena", "audioMonitor"
  ]

  static values = {
    eventsUrl: String,
    status: String,
    terminal: Boolean,
    interval: { type: Number, default: 1000 }
  }

  connect() {
    this.after = 0
    this.turns = 0
    this.reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.startedAt = null
    this.finished = this.terminalValue

    this.i18n = {
      listening: this.agentStateTarget.dataset.labelListening,
      thinking: this.agentStateTarget.dataset.labelThinking,
      speaking: this.agentStateTarget.dataset.labelSpeaking
    }

    if (this.finished) {
      this.element.classList.add("is-finished")
      return
    }

    this.startClock()
    this.schedule(200)
  }

  disconnect() {
    window.clearTimeout(this.timer)
    window.clearInterval(this.clockTimer)
    this.abortController?.abort()
  }

  schedule(delay = this.intervalValue) {
    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.poll(), delay)
  }

  async poll() {
    this.abortController = new AbortController()
    const url = `${this.eventsUrlValue}?after=${this.after}`

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this.abortController.signal
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()
      this.after = Number.isInteger(data.next_after) ? data.next_after : this.after
      this.applyEvents(data.events || [])
      if (data.status) this.applyStatus(data.status)

      if (data.terminal) {
        // Para quando terminou e não há mais eventos pendentes neste ciclo.
        if ((data.events || []).length === 0) {
          this.finish(data.report_html)
          return
        }
        this.schedule(250)
        return
      }

      this.schedule()
    } catch (error) {
      if (error.name !== "AbortError") this.schedule(Math.max(this.intervalValue, 3000))
    }
  }

  applyEvents(events) {
    for (const event of events) {
      switch (event.type) {
        case "participant_state":
          this.applyParticipantState(event.payload)
          break
        case "audio_levels":
          this.applyAudioLevels(event.payload)
          break
        case "turn":
          this.appendTurn(event.payload)
          break
        case "status":
          if (event.payload?.status) this.applyStatus(event.payload.status)
          break
        default:
          break
      }
    }
  }

  applyParticipantState(payload) {
    if (!payload) return
    const card = payload.participant === "agent" ? this.agentCardTarget : this.counterpartCardTarget
    const label = payload.participant === "agent" ? this.agentStateTarget : this.counterpartStateTarget
    const state = STATE_LABELS[payload.state] ? payload.state : "listening"
    card.dataset.state = state
    label.textContent = this.i18n[state] || state
  }

  // Níveis 0..1 por janela; usamos o pico recente para dar escala/pulso suave à onda, sem
  // animação agressiva e desligando sob prefers-reduced-motion.
  applyAudioLevels(payload) {
    if (!payload || this.reducedMotion) return
    this.setWave(this.waveAgentTarget, this.peak(payload.agent))
    this.setWave(this.waveCounterpartTarget, this.peak(payload.counterpart))
  }

  peak(levels) {
    if (!Array.isArray(levels) || levels.length === 0) return 0
    return Math.min(1, Math.max(0, ...levels))
  }

  setWave(element, level) {
    if (!element) return
    element.style.setProperty("--sim-level", level.toFixed(3))
  }

  appendTurn(payload) {
    if (!payload) return
    const text = (payload.text || "").trim()
    if (!text) return

    // Getter de target singular do Stimulus LANÇA "Missing target element" quando o
    // alvo some do DOM — e o optional chaining NÃO protege, pois a exceção ocorre ao
    // avaliar o getter. Após o 1º turno remover o placeholder, as chamadas seguintes
    // lançavam aqui, a exceção subia até o catch do poll (que só reagenda) e os demais
    // turnos nunca entravam no DOM (Turnos travava em 1). Guardamos com hasXTarget.
    if (this.hasTranscriptEmptyTarget) {
      this.transcriptEmptyTarget.remove()
    }

    const item = document.createElement("li")
    const who = payload.speaker === "agent" ? "agent" : "counterpart"
    item.className = `sim-transcript__row sim-transcript__row--${who}`

    const label = document.createElement("span")
    label.className = "sim-transcript__who"
    label.textContent = who === "agent" ? this.transcriptTarget.dataset.agentLabel : this.transcriptTarget.dataset.counterpartLabel

    const body = document.createElement("span")
    body.className = "sim-transcript__text"
    body.textContent = text

    item.append(label, body)
    this.transcriptTarget.append(item)
    item.scrollIntoView({ block: "nearest", behavior: this.reducedMotion ? "auto" : "smooth" })

    this.turns += 1
    if (this.hasTurnCountTarget) this.turnCountTarget.textContent = String(this.turns)
  }

  applyStatus(status) {
    if (status === this.statusValue) return
    this.statusValue = status
    if (this.hasStatusBadgeTarget) {
      this.statusBadgeTarget.innerHTML = this.statusBadgeHtml(status)
    }
    if (status === "running" && !this.startedAt) this.startClock()
  }

  statusBadgeHtml(status) {
    const label = this.statusBadgeTarget.dataset[`label${status.charAt(0).toUpperCase()}${status.slice(1)}`] || status
    // Mesmo markup de status_badge / SimulationsHelper::SIMULATION_STATUS_BADGES.
    const [tone, icon] = STATUS_BADGES[status] || ["neutral", "fa-circle-minus"]
    return `<span class="workspace-status workspace-status--${tone} workspace-status--icon" title="${label}"><i class="workspace-status__icon fa-solid ${icon}" aria-hidden="true"></i><span class="sr-only">${label}</span></span>`
  }

  startClock() {
    if (this.clockTimer) return
    this.startedAt = Date.now()
    this.clockTimer = window.setInterval(() => this.tickClock(), 1000)
    this.tickClock()
  }

  tickClock() {
    if (!this.startedAt || !this.hasClockTarget) return
    const elapsed = Math.floor((Date.now() - this.startedAt) / 1000)
    const minutes = String(Math.floor(elapsed / 60)).padStart(2, "0")
    const seconds = String(elapsed % 60).padStart(2, "0")
    this.clockTarget.textContent = `${minutes}:${seconds}`
  }

  finish(reportHtml) {
    this.finished = true
    window.clearTimeout(this.timer)
    window.clearInterval(this.clockTimer)
    this.element.classList.add("is-finished")

    // Encerra o monitor de áudio junto com a execução (fecha WSS e AudioContext).
    this.stopAudioMonitor()
    // Encerra os estados de voz: os dois lados voltam a "ouvindo" em repouso.
    this.resetAgents()
    // Mesmo cuidado do appendTurn: getter singular ausente lança; o optional chaining
    // não protege. Guardamos com hasLiveActionsTarget.
    if (this.hasLiveActionsTarget) {
      this.liveActionsTarget.setAttribute("hidden", "hidden")
    }

    if (reportHtml && this.hasReportTarget) {
      this.reportTarget.innerHTML = reportHtml
      // Reconecta controllers Stimulus dentro do HTML injetado (abas do transcript).
      this.reportTarget.scrollIntoView({ block: "start", behavior: this.reducedMotion ? "auto" : "smooth" })
    } else {
      // Sem HTML pronto (ex.: erro ao montar): recarrega para o show renderizar o relatório.
      window.location.reload()
    }
  }

  resetAgents() {
    for (const card of [this.agentCardTarget, this.counterpartCardTarget]) {
      card.dataset.state = "listening"
    }
    this.setWave(this.waveAgentTarget, 0)
    this.setWave(this.waveCounterpartTarget, 0)
  }

  // Pede ao controller de áudio (irmão) para encerrar o monitor quando a execução termina.
  stopAudioMonitor() {
    if (!this.hasAudioMonitorTarget) return
    const controller = this.application.getControllerForElementAndIdentifier(
      this.audioMonitorTarget,
      "simulation-audio"
    )
    controller?.stop()
    this.audioMonitorTarget.hidden = true
  }
}
