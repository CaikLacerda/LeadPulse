import { Controller } from "@hotwired/stimulus"
import { chartTheme, prefersReducedMotion } from "lib/analytics_chart_theme"
import { buildChartOptions, drillTarget } from "lib/analytics_chart_options"

// Único lugar que inicializa o ECharts. O arquivo da biblioteca só é baixado quando um gráfico
// aparece na tela. A tabela de dados da seção continua no documento (visível para leitores de
// tela e pelo botão "Tabela") e volta a aparecer se o gráfico não puder ser carregado.
// A visão 3D (ECharts GL) é opcional: só no desktop com WebGL, baixada no primeiro clique.
const DESKTOP = "(min-width: 1024px)"
// Troca 2D ↔ 3D: some e reaparece em ~200 ms no total (com a criação do gráfico), sem recarregar a página.
const FADE_MS = 80

const pause = (ms) => new Promise((resolve) => window.setTimeout(resolve, ms))

// Testa uma vez por página e devolve o contexto de teste na hora: o navegador limita quantos
// contextos WebGL ficam ativos.
let webGLSupport = null

function supportsWebGL() {
  if (webGLSupport !== null) return webGLSupport
  try {
    const gl = window.WebGLRenderingContext && document.createElement("canvas").getContext("webgl")
    webGLSupport = Boolean(gl)
    gl?.getExtension("WEBGL_lose_context")?.loseContext()
  } catch {
    webGLSupport = false
  }
  return webGLSupport
}

export default class extends Controller {
  static targets = ["canvas", "toggle", "mode", "viewSwitch", "view", "reset", "note", "note3d"]
  static values = { kind: String, data: Object, mode: String, view: { type: String, default: "2d" } }

  async connect() {
    this.element.classList.remove("is-ready", "is-table", "is-unavailable")
    this.element.classList.add("is-loading")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-pressed", "false")

    try {
      await import("echarts")
      if (!this.element.isConnected || this.chart) return

      // Uma página restaurada do cache do Turbo traz a cópia estática do gráfico anterior.
      // Uma cópia restaurada do cache do Turbo pode vir no estado 3D: sempre começa no 2D.
      this.switchView("2d")
      this.createChart()
      this.element.classList.add("is-ready")
      this.listen()
    } catch (error) {
      console.error("[analytics] gráfico indisponível", error)
      this.teardown()
      this.element.classList.add("is-unavailable")
    } finally {
      this.element.classList.remove("is-loading")
    }
  }

  disconnect() {
    this.teardown()
  }

  dataValueChanged() {
    if (this.chart) this.render()
  }

  // 2D em SVG (nítido, leve); 3D precisa de canvas/WebGL.
  createChart() {
    this.disposeChart()
    this.canvasTarget.replaceChildren()
    this.canvasTarget.removeAttribute("_echarts_instance_")
    const renderer = this.is3d ? "canvas" : "svg"
    this.chart = window.echarts.init(this.canvasTarget, null, { renderer })
    this.chart.on("click", (params) => this.drill(params))
    this.render()
  }

  get is3d() {
    return this.viewValue === "3d"
  }

  get kind() {
    return this.is3d ? `${this.kindValue}3d` : this.kindValue
  }

  render() {
    const context = { width: this.canvasTarget.clientWidth, mode: this.modeValue }
    this.chart.setOption(buildChartOptions(this.kind, this.dataValue, chartTheme(), context), { notMerge: true })
  }

  // Seletor [2D | 3D]. O ECharts GL só é baixado no primeiro pedido de 3D; se falhar, o
  // seletor some e o 2D continua. Métrica, filtros e período não mudam na troca.
  async setView(event) {
    const next = event.params.view
    if (next === this.viewValue || this.switching) return
    this.switching = true
    const button = event.currentTarget
    try {
      if (next === "3d") {
        button.setAttribute("aria-busy", "true")
        try {
          await import("echarts-gl")
        } catch (error) {
          console.error("[analytics] visão 3D indisponível", error)
          if (this.hasViewSwitchTarget) this.viewSwitchTarget.hidden = true
          return
        } finally {
          button.removeAttribute("aria-busy")
        }
        if (!this.chart) return
      }
      await this.switchView(next, { fade: true })
    } finally {
      this.switching = false
    }
  }

  async switchView(view, { fade = false } = {}) {
    const animate = fade && Boolean(this.chart) && !prefersReducedMotion()
    if (animate) {
      this.canvasTarget.classList.add("is-fading")
      await pause(FADE_MS)
      if (!this.element.isConnected) return
    }
    this.viewValue = view
    this.element.classList.toggle("is-3d", this.is3d)
    this.viewTargets.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.analyticsChartViewParam === view)))
    if (this.hasResetTarget) this.resetTarget.hidden = !this.is3d
    if (this.hasNoteTarget) this.noteTarget.hidden = this.is3d
    if (this.hasNote3dTarget) this.note3dTarget.hidden = !this.is3d
    if (this.chart) this.createChart()
    if (animate) window.requestAnimationFrame(() => this.canvasTarget.classList.remove("is-fading"))
  }

  // Redesenhar com notMerge volta a câmera à posição inicial.
  resetCamera() {
    if (this.chart && this.is3d) this.render()
  }

  // Seletor 2D/3D só aparece quando dá para usar; ao estreitar a janela, volta para o 2D.
  syncViewAvailability() {
    if (!this.hasViewSwitchTarget) return
    const available = this.desktop.matches && supportsWebGL()
    this.viewSwitchTarget.hidden = !available
    if (!available && this.is3d) this.switchView("2d")
  }

  // Alternância de medida do gráfico (ex.: Volume | Taxa no mapa de calor).
  setMode(event) {
    this.modeValue = event.params.mode
    this.modeTargets.forEach((button) => button.setAttribute("aria-pressed", String(button.dataset.analyticsChartModeParam === this.modeValue)))
    if (this.chart) this.render()
  }

  // Clique numa barra ou célula abre os itens correspondentes dentro do Analytics.
  drill(params) {
    const url = drillTarget(this.kind, this.dataValue, params)
    if (url) window.Turbo.visit(url, { frame: "analytics_content", action: "advance" })
  }

  toggleTable() {
    const showTable = !this.element.classList.contains("is-table")
    this.element.classList.toggle("is-table", showTable)
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-pressed", String(showTable))
    if (!showTable) this.chart?.resize()
  }

  listen() {
    this.redraw = () => window.requestAnimationFrame(() => this.chart && this.render())
    this.resizeObserver = new ResizeObserver(() => this.chart?.resize())
    this.resizeObserver.observe(this.canvasTarget)
    this.colorScheme = window.matchMedia("(prefers-color-scheme: dark)")
    this.colorScheme.addEventListener("change", this.redraw)
    window.addEventListener("appearance:changed", this.redraw)
    if (this.hasViewSwitchTarget) {
      // O ECharts GL cancela a roda do mouse mesmo sem zoom, prendendo a rolagem da página.
      // No 3D a roda não chega nele: a página rola normalmente.
      this.passWheel = (event) => this.is3d && event.stopPropagation()
      this.canvasTarget.addEventListener("wheel", this.passWheel, { capture: true })
      this.desktop = window.matchMedia(DESKTOP)
      this.availability = () => this.syncViewAvailability()
      this.desktop.addEventListener("change", this.availability)
      this.syncViewAvailability()
    }
  }

  // O ECharts GL não devolve o contexto WebGL no dispose, e o navegador limita quantos ficam
  // ativos (~16). Perde o contexto explicitamente para não acumular instâncias órfãs ao
  // alternar 2D/3D ou navegar pelo Turbo.
  disposeChart() {
    if (!this.chart) return
    const contexts = [...this.canvasTarget.querySelectorAll("canvas")]
      .map((canvas) => canvas.getContext("webgl") || canvas.getContext("experimental-webgl"))
      .filter(Boolean)
    this.chart.dispose()
    this.chart = null
    contexts.forEach((gl) => gl.getExtension("WEBGL_lose_context")?.loseContext())
  }

  teardown() {
    this.resizeObserver?.disconnect()
    this.colorScheme?.removeEventListener("change", this.redraw)
    window.removeEventListener("appearance:changed", this.redraw)
    this.desktop?.removeEventListener("change", this.availability)
    if (this.passWheel) this.canvasTarget.removeEventListener("wheel", this.passWheel, { capture: true })
    this.disposeChart()
    this.resizeObserver = null
    this.element.classList.remove("is-ready", "is-loading")
  }
}
