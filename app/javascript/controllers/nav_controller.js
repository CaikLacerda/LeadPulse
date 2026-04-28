import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "button"]

  connect() {
    this.close()
  }

  toggle() {
    const willOpen = this.panelTarget.classList.contains("hidden")
    this.panelTarget.classList.toggle("hidden", !willOpen)
    this.buttonTarget.setAttribute("aria-expanded", String(willOpen))
  }

  close() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("hidden")
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }
}
