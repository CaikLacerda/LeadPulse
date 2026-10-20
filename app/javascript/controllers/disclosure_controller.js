import { Controller } from "@hotwired/stimulus"

// Mostra ou esconde um elemento (ex.: linha de detalhe de uma tabela) indicado por aria-controls.
export default class extends Controller {
  toggle(event) {
    const button = event.currentTarget
    const target = document.getElementById(button.getAttribute("aria-controls"))
    if (!target) return

    const expanded = button.getAttribute("aria-expanded") !== "true"
    button.setAttribute("aria-expanded", String(expanded))
    target.hidden = !expanded
  }
}
