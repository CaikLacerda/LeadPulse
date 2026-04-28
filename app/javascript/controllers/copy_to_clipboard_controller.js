import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values = {
    source: String,
    defaultText: String,
    successText: String,
  }

  connect() {
    this.resetTimer = null
  }

  disconnect() {
    window.clearTimeout(this.resetTimer)
  }

  async copy(event) {
    event.preventDefault()

    const sourceElement = document.getElementById(this.sourceValue)
    if (!sourceElement) return

    await navigator.clipboard.writeText(sourceElement.value)
    this.showSuccessState()
  }

  showSuccessState() {
    if (!this.hasButtonTarget) return

    this.buttonTarget.textContent = this.successTextValue || "Copiado"
    window.clearTimeout(this.resetTimer)
    this.resetTimer = window.setTimeout(() => {
      this.buttonTarget.textContent = this.defaultTextValue || "Copiar"
    }, 2200)
  }
}
