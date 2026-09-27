import { Controller } from "@hotwired/stimulus"
import { chartTheme } from "lib/analytics_chart_theme"
import { buildChartOptions } from "lib/analytics_chart_options"

// Único lugar que inicializa o ECharts. O arquivo da biblioteca só é baixado quando um gráfico
// aparece na tela. A tabela de dados da seção continua no documento (visível para leitores de
// tela e pelo botão "Tabela") e volta a aparecer se o gráfico não puder ser carregado.
export default class extends Controller {
  static targets = ["canvas", "toggle"]
  static values = { kind: String, data: Object }

  async connect() {
    this.element.classList.remove("is-ready", "is-table", "is-unavailable")
    this.element.classList.add("is-loading")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-pressed", "false")

    try {
      await import("echarts")
      if (!this.element.isConnected || this.chart) return

      // Uma página restaurada do cache do Turbo traz a cópia estática do gráfico anterior.
      this.canvasTarget.replaceChildren()
      this.canvasTarget.removeAttribute("_echarts_instance_")
      this.chart = window.echarts.init(this.canvasTarget, null, { renderer: "svg" })
      this.render()
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

  render() {
    this.chart.setOption(buildChartOptions(this.kindValue, this.dataValue, chartTheme()), { notMerge: true })
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
  }

  teardown() {
    this.resizeObserver?.disconnect()
    this.colorScheme?.removeEventListener("change", this.redraw)
    window.removeEventListener("appearance:changed", this.redraw)
    this.chart?.dispose()
    this.chart = null
    this.resizeObserver = null
    this.element.classList.remove("is-ready", "is-loading")
  }
}
