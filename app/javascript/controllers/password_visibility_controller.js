import { Controller } from "@hotwired/stimulus"

// Mostra ou oculta a senha. O rótulo do botão é fixo ("Mostrar senha") e aria-pressed informa o estado.
export default class extends Controller {
  static targets = ["input", "button", "icon"]

  connect() {
    this.buttonTarget.hidden = false
    this.render(false)
  }

  toggle() {
    this.render(this.inputTarget.type === "password")
  }

  // Volta a ocultar ao enviar o formulário e antes do Turbo guardar a página em cache.
  hide() {
    this.render(false)
  }

  render(visible) {
    this.inputTarget.type = visible ? "text" : "password"
    this.buttonTarget.setAttribute("aria-pressed", String(visible))
    this.iconTarget.classList.toggle("fa-eye", !visible)
    this.iconTarget.classList.toggle("fa-eye-slash", visible)
  }
}
