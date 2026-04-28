// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import { cleanupTurboConfirm, installTurboConfirm } from "lib/custom_confirm"

installTurboConfirm()
document.addEventListener("turbo:load", installTurboConfirm)
document.addEventListener("turbo:before-cache", cleanupTurboConfirm)
