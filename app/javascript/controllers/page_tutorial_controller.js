import { Controller } from "@hotwired/stimulus"

const CARD_MARGIN = 16
const SPOTLIGHT_PADDING = 10
const SCROLL_DELAY_MS = 220
const ACTIVE_TARGET_CLASS = "workspace-tutorial-target--active"
const DIALOG_FALLBACK_WIDTH = 352
const DIALOG_FALLBACK_HEIGHT = 240

export default class extends Controller {
  static targets = [
    "overlay",
    "dialog",
    "spotlight",
    "title",
    "body",
    "progress",
    "backButton",
    "nextButton",
  ]

  static values = {
    stepsJson: String,
    nextLabel: String,
    finishLabel: String,
  }

  connect() {
    this.currentStepIndex = 0
    this.activeSteps = []
    this.activeElement = null
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleViewportChange = this.handleViewportChange.bind(this)
    this.scrollTimeout = null
  }

  disconnect() {
    this.teardownListeners()
    this.clearScrollTimeout()
  }

  start(event) {
    event?.preventDefault()

    this.activeSteps = this.availableSteps()
    if (this.activeSteps.length === 0) return

    this.currentStepIndex = 0
    this.open()
    this.renderCurrentStep()
  }

  close(event) {
    event?.preventDefault()

    this.overlayTarget.classList.add("hidden")
    this.overlayTarget.setAttribute("aria-hidden", "true")
    this.element.classList.remove("workspace-tutorial--open")
    this.clearActiveElement()
    this.teardownListeners()
    this.clearScrollTimeout()
  }

  next(event) {
    event?.preventDefault()

    if (this.currentStepIndex >= this.activeSteps.length - 1) {
      this.close()
      return
    }

    this.currentStepIndex += 1
    this.renderCurrentStep()
  }

  previous(event) {
    event?.preventDefault()
    if (this.currentStepIndex <= 0) return

    this.currentStepIndex -= 1
    this.renderCurrentStep()
  }

  dismissOnBackdrop(event) {
    if (this.dialogTarget.contains(event.target)) return
    this.close()
  }

  open() {
    this.overlayTarget.classList.remove("hidden")
    this.overlayTarget.setAttribute("aria-hidden", "false")
    this.element.classList.add("workspace-tutorial--open")
    document.addEventListener("keydown", this.handleKeydown)
    window.addEventListener("resize", this.handleViewportChange)
    window.addEventListener("scroll", this.handleViewportChange, true)

    window.requestAnimationFrame(() => {
      this.dialogTarget.focus()
    })
  }

  renderCurrentStep() {
    const step = this.activeSteps[this.currentStepIndex]
    if (!step) {
      this.close()
      return
    }

    const element = this.findElement(step.selector)
    if (!element) {
      this.activeSteps.splice(this.currentStepIndex, 1)

      if (this.currentStepIndex >= this.activeSteps.length) {
        this.currentStepIndex = Math.max(this.activeSteps.length - 1, 0)
      }

      if (this.activeSteps.length === 0) {
        this.close()
        return
      }

      this.renderCurrentStep()
      return
    }

    this.titleTarget.textContent = step.title
    this.bodyTarget.textContent = step.body
    this.progressTarget.textContent = `${this.currentStepIndex + 1} / ${this.activeSteps.length}`
    this.backButtonTarget.disabled = this.currentStepIndex === 0
    this.nextButtonTarget.textContent =
      this.currentStepIndex === this.activeSteps.length - 1 ? this.finishLabelValue : this.nextLabelValue
    this.setActiveElement(element)

    element.scrollIntoView({
      behavior: this.prefersReducedMotion ? "auto" : "smooth",
      block: "center",
      inline: "nearest",
    })

    window.requestAnimationFrame(() => {
      this.positionAround(element)
    })

    this.clearScrollTimeout()

    this.scrollTimeout = window.setTimeout(() => {
      this.positionAround(element)
    }, this.prefersReducedMotion ? 0 : SCROLL_DELAY_MS)
  }

  positionAround(element) {
    const rect = element.getBoundingClientRect()
    if (rect.width <= 0 || rect.height <= 0) return

    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight
    const top = Math.max(CARD_MARGIN, rect.top - SPOTLIGHT_PADDING)
    const left = Math.max(CARD_MARGIN, rect.left - SPOTLIGHT_PADDING)
    const width = Math.min(viewportWidth - (CARD_MARGIN * 2), rect.width + (SPOTLIGHT_PADDING * 2))
    const height = Math.min(viewportHeight - (CARD_MARGIN * 2), rect.height + (SPOTLIGHT_PADDING * 2))

    Object.assign(this.spotlightTarget.style, {
      top: `${top}px`,
      left: `${left}px`,
      width: `${width}px`,
      height: `${height}px`,
      borderRadius: window.getComputedStyle(element).borderRadius || "20px",
    })

    const dialogRect = this.dialogTarget.getBoundingClientRect()
    const dialogWidth = Math.max(dialogRect.width, Math.min(DIALOG_FALLBACK_WIDTH, viewportWidth - (CARD_MARGIN * 2)))
    const dialogHeight = Math.max(
      dialogRect.height,
      Math.min(this.dialogTarget.scrollHeight || DIALOG_FALLBACK_HEIGHT, viewportHeight - (CARD_MARGIN * 2)),
    )

    const centeredTop = this.clamp(
      rect.top + (rect.height / 2) - (dialogHeight / 2),
      CARD_MARGIN,
      viewportHeight - dialogHeight - CARD_MARGIN,
    )

    const centeredLeft = this.clamp(
      rect.left + (rect.width / 2) - (dialogWidth / 2),
      CARD_MARGIN,
      viewportWidth - dialogWidth - CARD_MARGIN,
    )

    const candidates = [
      {
        side: "right",
        top: centeredTop,
        left: rect.right + CARD_MARGIN,
      },
      {
        side: "left",
        top: centeredTop,
        left: rect.left - dialogWidth - CARD_MARGIN,
      },
      {
        side: "bottom",
        top: rect.bottom + CARD_MARGIN,
        left: centeredLeft,
      },
      {
        side: "top",
        top: rect.top - dialogHeight - CARD_MARGIN,
        left: centeredLeft,
      },
    ]

    const fittingCandidate = candidates.find((candidate) =>
      this.dialogFitsViewport(candidate, dialogWidth, dialogHeight, viewportWidth, viewportHeight),
    )

    const fallbackCandidate = {
      top: CARD_MARGIN,
      left: viewportWidth - dialogWidth - CARD_MARGIN,
    }

    const chosen = fittingCandidate || fallbackCandidate

    Object.assign(this.dialogTarget.style, {
      top: `${this.clamp(chosen.top, CARD_MARGIN, viewportHeight - dialogHeight - CARD_MARGIN)}px`,
      left: `${this.clamp(chosen.left, CARD_MARGIN, viewportWidth - dialogWidth - CARD_MARGIN)}px`,
      right: "auto",
      bottom: "auto",
    })
  }

  availableSteps() {
    return this.parsedSteps.filter((step) => this.findElement(step.selector))
  }

  findElement(selector) {
    if (!selector) return null

    const element = document.querySelector(selector)
    if (!element) return null

    const style = window.getComputedStyle(element)
    const rect = element.getBoundingClientRect()

    if (style.display === "none" || style.visibility === "hidden" || rect.width <= 0 || rect.height <= 0) {
      return null
    }

    return element
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
      return
    }

    if (event.key === "ArrowRight") {
      this.next(event)
      return
    }

    if (event.key === "ArrowLeft") {
      this.previous(event)
    }
  }

  handleViewportChange() {
    const step = this.activeSteps[this.currentStepIndex]
    if (!step || this.overlayTarget.classList.contains("hidden")) return

    const element = this.findElement(step.selector)
    if (!element) return

    this.positionAround(element)
  }

  teardownListeners() {
    document.removeEventListener("keydown", this.handleKeydown)
    window.removeEventListener("resize", this.handleViewportChange)
    window.removeEventListener("scroll", this.handleViewportChange, true)
  }

  setActiveElement(element) {
    if (this.activeElement === element) return

    this.clearActiveElement()
    this.activeElement = element
    this.activeElement.classList.add(ACTIVE_TARGET_CLASS)
  }

  clearActiveElement() {
    if (!this.activeElement) return

    this.activeElement.classList.remove(ACTIVE_TARGET_CLASS)
    this.activeElement = null
  }

  clearScrollTimeout() {
    if (!this.scrollTimeout) return

    window.clearTimeout(this.scrollTimeout)
    this.scrollTimeout = null
  }

  dialogFitsViewport(candidate, dialogWidth, dialogHeight, viewportWidth, viewportHeight) {
    return (
      candidate.left >= CARD_MARGIN &&
      candidate.top >= CARD_MARGIN &&
      candidate.left + dialogWidth <= viewportWidth - CARD_MARGIN &&
      candidate.top + dialogHeight <= viewportHeight - CARD_MARGIN
    )
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  }

  get prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  get parsedSteps() {
    if (this._parsedSteps) return this._parsedSteps

    try {
      const value = JSON.parse(this.stepsJsonValue || "[]")
      this._parsedSteps = Array.isArray(value) ? value : []
    } catch (_error) {
      this._parsedSteps = []
    }

    return this._parsedSteps
  }
}
