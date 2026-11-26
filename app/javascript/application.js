// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import { cleanupTurboConfirm, installTurboConfirm } from "lib/custom_confirm"

installTurboConfirm()
document.addEventListener("turbo:load", installTurboConfirm)
document.addEventListener("turbo:before-cache", cleanupTurboConfirm)

// O Turbo troca apenas o <body> nas navegações; o tema de cada página vem em body[data-page-theme].
document.addEventListener("turbo:before-render", (event) => {
  const theme = event.detail.newBody?.dataset.pageTheme
  if (theme) {
    document.documentElement.dataset.theme = theme
  } else {
    delete document.documentElement.dataset.theme
  }
})
