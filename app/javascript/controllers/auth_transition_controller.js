import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "leadpulse:auth-transition-direction"

export default class extends Controller {
  connect() {
    const direction = sessionStorage.getItem(STORAGE_KEY) || this.element.dataset.authTransitionDirection || "forward"

    sessionStorage.removeItem(STORAGE_KEY)
    this.element.dataset.authTransitionDirection = direction
    this.element.dataset.authTransitionActive = "true"

    requestAnimationFrame(() => {
      this.element.dataset.authTransitionReady = "true"
    })
  }

  rememberDirection(event) {
    const direction = event.currentTarget.dataset.authTransitionDirection || "forward"
    sessionStorage.setItem(STORAGE_KEY, direction)
  }
}
