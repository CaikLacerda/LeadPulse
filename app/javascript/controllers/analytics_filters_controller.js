import { Controller } from "@hotwired/stimulus"

// Barra de filtros do Analytics: envia sozinha ao mudar um campo (com espera curta) e mantém
// a URL limpa, sem campos vazios nem valores padrão. O botão "Filtrar" continua disponível
// para quem navega pelo teclado ou sem JavaScript.
export default class extends Controller {
  static targets = ["period", "custom", "from", "to", "fields", "toggle"]

  connect() {
    this.toggleCustom()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  change() {
    this.toggleCustom()
    if (this.customSelected && !(this.fromTarget.value && this.toTarget.value)) return

    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), 250)
  }

  // Desabilitar um campo o tira do envio; ele volta a ficar ativo logo depois.
  clean() {
    const skipped = Array.from(this.element.elements).filter((field) => {
      if (!field.name || field.disabled || field.type === "submit") return false
      if (field.value === "") return true
      if (field.dataset.default && field.value === field.dataset.default) return true
      return !this.customSelected && (field.name === "de" || field.name === "ate")
    })

    skipped.forEach((field) => { field.disabled = true })
    setTimeout(() => skipped.forEach((field) => { field.disabled = false }), 0)
  }

  // No celular, os campos ficam recolhidos atrás do botão "Filtros".
  toggleFields() {
    const open = !this.fieldsTarget.classList.contains("is-open")
    this.fieldsTarget.classList.toggle("is-open", open)
    this.toggleTarget.setAttribute("aria-expanded", String(open))
  }

  toggleCustom() {
    if (!this.hasCustomTarget) return

    this.customTarget.hidden = !this.customSelected
  }

  get customSelected() {
    return this.hasPeriodTarget && this.periodTarget.value === "personalizado"
  }
}
