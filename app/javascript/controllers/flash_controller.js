import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 5000 },
  }

  connect() {
    this.dismiss = this.dismiss.bind(this)
    this.handleAnimationEnd = this.handleAnimationEnd.bind(this)

    this.dismissed = false
    this.raf = null
    this.timeout = window.setTimeout(this.dismiss, this.delayValue)
    this.element.addEventListener("animationend", this.handleAnimationEnd)
  }

  disconnect() {
    window.clearTimeout(this.timeout)
    if (this.raf) window.cancelAnimationFrame(this.raf)
    this.element.removeEventListener("animationend", this.handleAnimationEnd)
  }

  dismiss() {
    if (this.dismissed) return

    this.dismissed = true
    window.clearTimeout(this.timeout)
    this.raf = window.requestAnimationFrame(() => {
      if (!this.element.isConnected) return
      this.element.classList.add("app-flash--dismissing")
    })
  }

  handleAnimationEnd(event) {
    if (event.target !== this.element) return
    if (!this.dismissed) return

    this.element.remove()
  }
}
