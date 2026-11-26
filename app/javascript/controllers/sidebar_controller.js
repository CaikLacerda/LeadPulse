import { Controller } from "@hotwired/stimulus"

const COOKIE_NAME = "lp_sidebar"
const COLLAPSED_CLASS = "app-shell--collapsed"
const MOBILE_OPEN_CLASS = "app-shell--nav-open"

// Sidebar do workspace: recolhe no desktop (preferência salva em cookie) e abre como gaveta no mobile.
export default class extends Controller {
  static targets = ["menuButton", "collapseButton"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    this.closeMobile = this.closeMobile.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("turbo:before-visit", this.closeMobile)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("turbo:before-visit", this.closeMobile)
  }

  openMobile() {
    this.element.classList.add(MOBILE_OPEN_CLASS)
    this.menuButtonTargets.forEach((button) => button.setAttribute("aria-expanded", "true"))
    this.element.querySelector(".app-nav-link")?.focus()
  }

  closeMobile() {
    if (!this.element.classList.contains(MOBILE_OPEN_CLASS)) return

    this.element.classList.remove(MOBILE_OPEN_CLASS)
    this.menuButtonTargets.forEach((button) => button.setAttribute("aria-expanded", "false"))
  }

  toggleCollapsed() {
    const collapsed = this.element.classList.toggle(COLLAPSED_CLASS)
    document.cookie = `${COOKIE_NAME}=${collapsed ? "collapsed" : "expanded"}; path=/; max-age=31536000; samesite=lax`
    this.collapseButtonTargets.forEach((button) => button.setAttribute("aria-pressed", String(collapsed)))
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.closeMobile()
  }
}
