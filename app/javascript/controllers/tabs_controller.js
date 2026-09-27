import { Controller } from "@hotwired/stimulus"

// Abas de páginas de detalhe. A aba ativa fica no hash da URL para permitir links diretos.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const fromHash = this.tabTargets.find((tab) => `#${tab.dataset.tabsId}` === window.location.hash)
    this.select(fromHash || this.tabTargets[0], { updateHash: false })
  }

  show(event) {
    event.preventDefault()
    this.select(event.currentTarget, { updateHash: true })
  }

  keydown(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    let next = null

    if (event.key === "ArrowRight") next = this.tabTargets[(index + 1) % this.tabTargets.length]
    if (event.key === "ArrowLeft") next = this.tabTargets[(index - 1 + this.tabTargets.length) % this.tabTargets.length]
    if (!next) return

    event.preventDefault()
    this.select(next, { updateHash: true })
    next.focus()
  }

  select(activeTab, { updateHash }) {
    if (!activeTab) return

    this.tabTargets.forEach((tab) => {
      const active = tab === activeTab
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.id !== activeTab.getAttribute("aria-controls")
    })

    if (updateHash) history.replaceState(history.state, "", `#${activeTab.dataset.tabsId}`)
  }
}
