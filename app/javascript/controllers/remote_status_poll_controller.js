import { Controller } from "@hotwired/stimulus"

// Reconciliação leve para as telas locais enquanto a API processa a chamada.
// O caminho de áudio não passa pelo Rails; este controller apenas atualiza a
// projeção visual sem exigir que a pessoa clique em "Consultar status".
export default class extends Controller {
  static values = {
    urls: Array,
    interval: { type: Number, default: 8000 }
  }

  connect() {
    if (this.urlsValue.length > 0) this.schedule(1200)
  }

  disconnect() {
    window.clearTimeout(this.timer)
    this.abortController?.abort()
  }

  schedule(delay = this.intervalValue) {
    window.clearTimeout(this.timer)
    this.timer = window.setTimeout(() => this.sync(), delay)
  }

  async sync() {
    this.abortController = new AbortController()
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const states = []
      // As páginas são paginadas (5/10 itens), portanto a reconciliação fica
      // deliberadamente limitada ao que está visível.
      for (const url of this.urlsValue) {
        const response = await fetch(url, {
          method: "POST",
          credentials: "same-origin",
          headers: {
            Accept: "application/json",
            "X-CSRF-Token": csrfToken || ""
          },
          signal: this.abortController.signal
        })
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        states.push(await response.json())
      }

      if (states.some((state) => state.terminal || state.changed)) {
        window.location.reload()
        return
      }
      this.schedule()
    } catch (error) {
      if (error.name !== "AbortError") this.schedule(Math.max(this.intervalValue, 12000))
    }
  }
}
