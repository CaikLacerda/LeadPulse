import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    active: Boolean,
    url: String,
    fingerprint: String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    if (this.activeValue) this.schedule(900)
  }

  disconnect() {
    window.clearTimeout(this.timer)
  }

  schedule(delay = this.intervalValue) {
    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.check(), delay)
  }

  async check() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const progress = await response.json()
      if (!progress.active || progress.fingerprint !== this.fingerprintValue) {
        window.location.reload()
        return
      }

      this.schedule()
    } catch (_error) {
      this.schedule(4000)
    }
  }
}
