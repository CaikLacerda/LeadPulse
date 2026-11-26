import { Controller } from "@hotwired/stimulus"

// Menu móvel do header público.
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

  close(event) {
    const wasOpen = this.hasPanelTarget && !this.panelTarget.classList.contains("hidden")

    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("hidden")
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
      // Esc fecha o menu e devolve o foco ao botão que o abriu.
      if (wasOpen && event?.type === "keydown") this.buttonTarget.focus()
    }
  }
}
