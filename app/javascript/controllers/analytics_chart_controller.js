import { Controller } from "@hotwired/stimulus"
import { chartTheme } from "lib/analytics_chart_theme"
import { buildChartOptions, drillTarget } from "lib/analytics_chart_options"

// Único lugar que inicializa o ECharts. O arquivo da biblioteca só é baixado quando um gráfico
// aparece na tela. A tabela de dados da seção continua no documento (visível para leitores de
// tela e pelo botão "Tabela") e volta a aparecer se o gráfico não puder ser carregado.
// A visão 3D (ECharts GL) é opcional: só no desktop com WebGL, baixada no primeiro clique.
const DESKTOP = "(min-width: 1024px)"

function supportsWebGL() {
  try {
    return Boolean(window.WebGLRenderingContext && document.createElement("canvas").getContext("webgl"))
  } catch {
    return false
  }
}

export default class extends Controller {
  static targets = ["canvas", "toggle", "mode", "view", "reset", "note", "note3d"]
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
    this.chart?.dispose()
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

  async toggleView() {
    const next = this.is3d ? "2d" : "3d"
    if (next === "3d") {
      this.viewTarget.disabled = true
      try {
        await import("echarts-gl")
      } catch (error) {
        console.error("[analytics] visão 3D indisponível", error)
        this.viewTarget.hidden = true
        return
      } finally {
        this.viewTarget.disabled = false
      }
      if (!this.chart) return
    }
    this.switchView(next)
  }

  switchView(view) {
    this.viewValue = view
    this.element.classList.toggle("is-3d", this.is3d)
    if (this.hasViewTarget) this.viewTarget.setAttribute("aria-pressed", String(this.is3d))
    if (this.hasResetTarget) this.resetTarget.hidden = !this.is3d
    if (this.hasNoteTarget) this.noteTarget.hidden = this.is3d
    if (this.hasNote3dTarget) this.note3dTarget.hidden = !this.is3d
    if (this.chart) this.createChart()
  }

  // Redesenhar com notMerge volta a câmera à posição inicial.
  resetCamera() {
    if (this.chart && this.is3d) this.render()
  }

  // Botão 3D só aparece quando dá para usar; ao estreitar a janela, volta para o 2D.
  syncViewAvailability() {
    if (!this.hasViewTarget) return
    const available = this.desktop.matches && supportsWebGL()
    this.viewTarget.hidden = !available
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
    if (this.hasViewTarget) {
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

  teardown() {
    this.resizeObserver?.disconnect()
    this.colorScheme?.removeEventListener("change", this.redraw)
    window.removeEventListener("appearance:changed", this.redraw)
    this.desktop?.removeEventListener("change", this.availability)
    if (this.passWheel) this.canvasTarget.removeEventListener("wheel", this.passWheel, { capture: true })
    this.chart?.dispose()
    this.chart = null
    this.resizeObserver = null
    this.element.classList.remove("is-ready", "is-loading")
  }
}
