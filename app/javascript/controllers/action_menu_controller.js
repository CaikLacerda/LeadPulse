import { Controller } from "@hotwired/stimulus"

const MENU_GAP = 4
const VIEWPORT_MARGIN = 8

export default class extends Controller {
  static values = { floating: Boolean }

  connect() {
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    this.handleDocumentKeydown = this.handleDocumentKeydown.bind(this)
    this.handleToggle = this.handleToggle.bind(this)
    this.handleViewportChange = this.handleViewportChange.bind(this)

    this.element.addEventListener("toggle", this.handleToggle)
    document.addEventListener("click", this.handleDocumentClick)
    document.addEventListener("keydown", this.handleDocumentKeydown)
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.handleToggle)
    document.removeEventListener("click", this.handleDocumentClick)
    document.removeEventListener("keydown", this.handleDocumentKeydown)
    this.stopTrackingViewport()
  }

  close() {
    this.element.open = false
  }

  handleToggle() {
    if (!this.element.open) {
      this.stopTrackingViewport()
      return
    }

    document.querySelectorAll('details[data-controller~="action-menu"]').forEach((menu) => {
      if (menu !== this.element) menu.open = false
    })

    if (this.floatingValue) this.positionFloatingMenu()
  }

  // Menus dentro de tabelas usam posição fixa para não serem cortados pelo overflow do container.
  positionFloatingMenu() {
    const summary = this.element.querySelector("summary")
    const menu = this.element.querySelector(".workspace-menu")
    if (!summary || !menu) return

    menu.classList.add("workspace-menu--floating")
    menu.style.visibility = "hidden"

    window.requestAnimationFrame(() => {
      const trigger = summary.getBoundingClientRect()
      const { width, height } = menu.getBoundingClientRect()
      const spaceBelow = window.innerHeight - trigger.bottom
      const top = spaceBelow < height + MENU_GAP + VIEWPORT_MARGIN && trigger.top > height + MENU_GAP
        ? trigger.top - height - MENU_GAP
        : trigger.bottom + MENU_GAP
      const left = Math.min(
        Math.max(VIEWPORT_MARGIN, trigger.right - width),
        window.innerWidth - width - VIEWPORT_MARGIN
      )

      Object.assign(menu.style, { position: "fixed", top: `${top}px`, left: `${left}px`, right: "auto", visibility: "" })
      this.startTrackingViewport()
    })
  }

  startTrackingViewport() {
    window.addEventListener("scroll", this.handleViewportChange, true)
    window.addEventListener("resize", this.handleViewportChange)
  }

  stopTrackingViewport() {
    window.removeEventListener("scroll", this.handleViewportChange, true)
    window.removeEventListener("resize", this.handleViewportChange)
  }

  handleViewportChange(event) {
    if (event?.type === "scroll" && this.element.contains(event.target)) return
    this.close()
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
    this.element.querySelector("summary")?.focus()
  }
}
