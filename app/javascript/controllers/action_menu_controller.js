import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    this.handleDocumentKeydown = this.handleDocumentKeydown.bind(this)
    this.handleToggle = this.handleToggle.bind(this)

    this.element.addEventListener("toggle", this.handleToggle)
    document.addEventListener("click", this.handleDocumentClick)
    document.addEventListener("keydown", this.handleDocumentKeydown)
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.handleToggle)
    document.removeEventListener("click", this.handleDocumentClick)
    document.removeEventListener("keydown", this.handleDocumentKeydown)
  }

  close() {
    this.element.open = false
  }

  handleToggle() {
    if (!this.element.open) return

    document.querySelectorAll('details[data-controller~="action-menu"]').forEach((menu) => {
      if (menu !== this.element) menu.open = false
    })
  }

  handleDocumentClick(event) {
    if (!this.element.open) return
    if (this.element.contains(event.target)) return

    this.close()
  }

  handleDocumentKeydown(event) {
    if (event.key !== "Escape") return
    if (!this.element.open) return

    this.close()
  }
}
