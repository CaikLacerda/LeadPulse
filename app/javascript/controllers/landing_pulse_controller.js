import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hero", "stage", "tab", "panel", "screen"]

  connect() {
    this.activeIndex = 0
    this.applyActive()
    this.prepareRevealAnimations()
  }

  disconnect() {
    if (this.revealObserver) {
      this.revealObserver.disconnect()
    }
  }

  track(event) {
    if (!this.hasHeroTarget) return

    const rect = this.heroTarget.getBoundingClientRect()
    const x = this.bound((event.clientX - rect.left) / rect.width)
    const y = this.bound((event.clientY - rect.top) / rect.height)

    this.heroTarget.style.setProperty("--mx", `${(x * 100).toFixed(1)}%`)
    this.heroTarget.style.setProperty("--my", `${(y * 100).toFixed(1)}%`)

    if (this.hasStageTarget) {
      this.stageTarget.style.setProperty("--tilt-x", `${((y - 0.5) * -7).toFixed(2)}deg`)
      this.stageTarget.style.setProperty("--tilt-y", `${((x - 0.5) * 9).toFixed(2)}deg`)
    }
  }

  select(event) {
    this.activeIndex = Number(event.currentTarget.dataset.index || 0)
    this.applyActive()
  }

  applyActive() {
    this.tabTargets.forEach((tab, index) => {
      const active = index === this.activeIndex
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
      tab.setAttribute("tabindex", active ? "0" : "-1")
    })

    this.panelTargets.forEach((panel, index) => {
      const active = index === this.activeIndex
      panel.classList.toggle("is-active", active)
      panel.setAttribute("aria-hidden", active ? "false" : "true")
    })

    if (this.hasScreenTarget) {
      this.screenTarget.dataset.mode = this.activeIndex
    }
  }

  bound(value) {
    return Math.min(1, Math.max(0, value))
  }

  prepareRevealAnimations() {
    if (!("IntersectionObserver" in window)) return

    const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const targets = this.element.querySelectorAll([
      ".landing-section-heading",
      ".landing-product__mock",
      ".landing-product__side article",
      ".landing-drama__copy",
      ".landing-compare article",
      ".landing-demo__controls",
      ".landing-demo__screen",
      ".landing-outcomes__grid article",
      ".landing-flow__copy",
      ".landing-flow__steps article",
      ".landing-plans__grid article",
      ".landing-faq__list details",
      ".landing-close h2",
      ".landing-close p",
      ".landing-close .landing-button"
    ].join(","))

    targets.forEach((target, index) => {
      target.classList.add("landing-motion-ready")
      target.style.setProperty("--motion-delay", `${Math.min(index % 6, 5) * 80}ms`)

      if (prefersReducedMotion) {
        target.classList.add("is-visible")
      }
    })

    if (prefersReducedMotion) return

    this.revealObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return

        entry.target.classList.add("is-visible")
        this.revealObserver.unobserve(entry.target)
      })
    }, {
      rootMargin: "0px 0px -12% 0px",
      threshold: 0.16
    })

    targets.forEach((target) => this.revealObserver.observe(target))
  }
}
