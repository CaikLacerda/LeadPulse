import { Controller } from "@hotwired/stimulus"

const COOKIE_NAME = "lp_theme"

// Seletor de tema (Claro, Escuro, Sistema). A preferência vai para um cookie lido no servidor,
// então a página seguinte já é renderizada no tema certo, sem piscar.
export default class extends Controller {
  static targets = ["option"]

  select(event) {
    const theme = event.params.theme
    document.cookie = `${COOKIE_NAME}=${theme}; path=/; max-age=31536000; samesite=lax`

    // Sem isso, cada elemento com transição de cor "desbota" até o novo tema em vez de trocar de uma vez.
    const root = document.documentElement
    root.classList.add("theme-switching")
    window.requestAnimationFrame(() => window.requestAnimationFrame(() => root.classList.remove("theme-switching")))

    if (theme === "system") {
      delete document.documentElement.dataset.theme
      delete document.body.dataset.pageTheme
    } else {
      document.documentElement.dataset.theme = theme
      document.body.dataset.pageTheme = theme
    }

    this.optionTargets.forEach((option) => {
      option.setAttribute("aria-pressed", String(option.dataset.appearanceThemeParam === theme))
    })
  }
}
