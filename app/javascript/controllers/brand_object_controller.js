import { Controller } from "@hotwired/stimulus"

// Ícone 3D da marca nas telas de acesso. Arrastar gira a peça; ao soltar ela segue com inércia e
// volta devagar à pose de descanso. Com movimento reduzido a peça só gira enquanto é arrastada.
const REST = { x: 12, y: -24 }
const TURN_PER_PX = 0.45
const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

export default class extends Controller {
  static targets = ["piece"]

  connect() {
    this.reducedMotion = matchMedia("(prefers-reduced-motion: reduce)")
    this.angle = { ...REST }
    this.velocity = 0
    this.render()
  }

  disconnect() {
    cancelAnimationFrame(this.frame)
  }

  grab(event) {
    if (event.pointerType === "mouse" && event.button !== 0) return

    cancelAnimationFrame(this.frame)
    this.element.setPointerCapture(event.pointerId)
    this.element.classList.add("is-dragging")
    this.drag = { x: event.clientX, y: event.clientY, angle: { ...this.angle }, lastX: event.clientX, lastTime: event.timeStamp }
    this.velocity = 0
  }

  move(event) {
    if (!this.drag) return

    this.angle.y = this.drag.angle.y + (event.clientX - this.drag.x) * TURN_PER_PX
    this.angle.x = clamp(this.drag.angle.x - (event.clientY - this.drag.y) * 0.25, -30, 40)
    // Degrees per frame (~16 ms), used for the throw after release.
    const elapsed = Math.max(1, event.timeStamp - this.drag.lastTime)
    this.velocity = ((event.clientX - this.drag.lastX) * TURN_PER_PX / elapsed) * 16
    this.drag.lastX = event.clientX
    this.drag.lastTime = event.timeStamp
    this.render()
  }

  release() {
    if (!this.drag) return

    this.drag = null
    this.element.classList.remove("is-dragging")
    if (!this.reducedMotion.matches) this.frame = requestAnimationFrame(() => this.settle())
  }

  // Inertia first; once it slows down, ease back to the resting pose the shortest way around.
  settle() {
    this.angle.y += this.velocity
    this.velocity *= 0.94

    if (Math.abs(this.velocity) < 0.05) {
      this.velocity = 0
      const target = REST.y + Math.round((this.angle.y - REST.y) / 360) * 360
      this.angle.y += (target - this.angle.y) * 0.08
      this.angle.x += (REST.x - this.angle.x) * 0.08
      if (Math.abs(target - this.angle.y) < 0.1 && Math.abs(REST.x - this.angle.x) < 0.1) {
        this.angle = { ...REST }
        this.render()
        return
      }
    }

    this.render()
    this.frame = requestAnimationFrame(() => this.settle())
  }

  render() {
    const style = this.pieceTarget.style
    style.setProperty("--rx", `${this.angle.x}deg`)
    style.setProperty("--ry", `${this.angle.y}deg`)
    // The highlight slides across the face as it turns toward or away from the light.
    style.setProperty("--sheen", `${50 - Math.sin(this.angle.y * Math.PI / 180) * 45}%`)
  }
}
