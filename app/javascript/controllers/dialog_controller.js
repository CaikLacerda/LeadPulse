import { Controller } from "@hotwired/stimulus"

// Diálogo nativo (<dialog>): foco preso dentro, Esc fecha, e o foco volta a quem abriu.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    this.opener = event?.currentTarget
    this.dialogTarget.showModal()
    this.dialogTarget.querySelector("input, select, textarea")?.focus()
  }

  close() {
    this.dialogTarget.close()
    this.opener?.focus()
  }

  // Clique fora do painel (no fundo escurecido) fecha.
  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
