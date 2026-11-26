import { Controller } from "@hotwired/stimulus"

// Troca de papel na tabela da equipe: o botão "Salvar" só aparece quando o papel mudou.
// Sem JavaScript, o botão fica sempre visível.
export default class extends Controller {
  static targets = ["select", "submit"]

  connect() {
    this.changed()
  }

  changed() {
    this.submitTarget.hidden = this.selectTarget.value === this.selectTarget.dataset.initial
  }
}
