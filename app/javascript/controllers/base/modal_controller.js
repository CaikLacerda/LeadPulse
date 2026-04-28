import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "panel"]

  connect() {
    this.handleDocumentKeydown = this.handleDocumentKeydown.bind(this)
    document.addEventListener("keydown", this.handleDocumentKeydown)
    this.syncBodyState()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleDocumentKeydown)
    this.syncBodyState()
  }

  open(event) {
    event?.preventDefault()
    if (!this.hasModalTarget) return

    this.modalTarget.classList.remove("hidden")
    this.syncBodyState()

    window.requestAnimationFrame(() => {
      this.panelTarget?.focus()
    })
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasModalTarget) return

    this.modalTarget.classList.add("hidden")
    this.syncBodyState()
  }

  isOpen() {
    return this.hasModalTarget && !this.modalTarget.classList.contains("hidden")
  }

  syncBodyState() {
    document.body.classList.toggle("overflow-hidden", this.isOpen())
  }

  handleDocumentKeydown(event) {
    if (event.key !== "Escape" || !this.isOpen()) return
    this.close()
  }
}
