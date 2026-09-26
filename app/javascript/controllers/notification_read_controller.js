import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, keys: Array }
  static targets = ["badge", "count", "item"]

  connect() {
    this.markAsRead = this.markAsRead.bind(this)
    this.element.addEventListener("toggle", this.markAsRead)
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.markAsRead)
  }

  async markAsRead() {
    if (!this.element.open || this.keysValue.length === 0) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        Accept: "application/json"
      },
      body: JSON.stringify({ notification_keys: this.keysValue })
    })

    if (!response.ok) return

    this.itemTargets.forEach((item) => {
      item.classList.remove("app-notification-item--unread")
      item.classList.add("app-notification-item--read")
    })
    this.badgeTargets.forEach((badge) => badge.remove())
    this.countTargets.forEach((count) => count.remove())
    this.keysValue = []
  }
}
