import { Controller } from "@hotwired/stimulus"

// Botão "Guia da tela" da topbar: dispara o tutorial da página atual (page_tutorial_controller).
export default class extends Controller {
  launch(event) {
    event.preventDefault()
    window.dispatchEvent(new CustomEvent("workspace:tutorial"))
  }
}
