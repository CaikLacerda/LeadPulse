const confirmModalState = {
  root: null,
  panel: null,
  title: null,
  message: null,
  accept: null,
  cancelButtons: [],
  resolve: null,
  restoreFocusTo: null,
  keydownHandler: null,
  closeTimer: null,
}

const resetConfirmModalState = () => {
  confirmModalState.root = null
  confirmModalState.panel = null
  confirmModalState.title = null
  confirmModalState.message = null
  confirmModalState.accept = null
  confirmModalState.cancelButtons = []
  confirmModalState.resolve = null
  confirmModalState.restoreFocusTo = null
  confirmModalState.keydownHandler = null
  confirmModalState.closeTimer = null
}

const confirmCopyFor = (message, element) => {
  const source = element?.closest?.("[data-turbo-confirm], form") || element
  const dataset = source?.dataset || {}

  return {
    title: dataset.turboConfirmTitle || "Confirmar ação",
    message: dataset.turboConfirm || message || "Deseja continuar?",
    confirmLabel: dataset.turboConfirmConfirmLabel || "Confirmar",
    cancelLabel: dataset.turboConfirmCancelLabel || "Cancelar",
  }
}

const closeConfirmModal = (confirmed) => {
  if (!confirmModalState.root || !confirmModalState.resolve) return

  const { root, resolve, restoreFocusTo, keydownHandler } = confirmModalState
  confirmModalState.resolve = null
  confirmModalState.restoreFocusTo = null

  root.classList.remove("app-confirm--open")
  root.setAttribute("aria-hidden", "true")
  document.body.classList.remove("app-confirm-open")

  if (keydownHandler) {
    document.removeEventListener("keydown", keydownHandler)
    confirmModalState.keydownHandler = null
  }

  window.clearTimeout(confirmModalState.closeTimer)
  confirmModalState.closeTimer = window.setTimeout(() => {
    root.classList.add("hidden")
    if (restoreFocusTo && typeof restoreFocusTo.focus === "function") restoreFocusTo.focus()
  }, 180)

  resolve(confirmed)
}

const ensureConfirmModal = () => {
  if (confirmModalState.root && !document.body.contains(confirmModalState.root)) {
    resetConfirmModalState()
  }

  if (confirmModalState.root) return confirmModalState

  const root = document.createElement("div")
  root.id = "app-confirm"
  root.className = "app-confirm hidden"
  root.setAttribute("aria-hidden", "true")
  root.innerHTML = `
    <div class="app-confirm__backdrop" data-confirm-cancel></div>
    <div class="app-confirm__panel" role="alertdialog" aria-modal="true" aria-labelledby="app-confirm-title" aria-describedby="app-confirm-message" tabindex="-1">
      <div class="app-confirm__accent" aria-hidden="true"></div>
      <div class="app-confirm__header">
        <span class="app-confirm__icon" aria-hidden="true">⚡</span>
        <div class="app-confirm__copy">
          <p class="app-confirm__eyebrow">LeadPulse</p>
          <h2 class="app-confirm__title" id="app-confirm-title">Confirmar ação</h2>
        </div>
      </div>
      <p class="app-confirm__message" id="app-confirm-message">Deseja continuar?</p>
      <div class="app-confirm__actions">
        <button type="button" class="app-confirm__button app-confirm__button--secondary" data-confirm-cancel>Cancelar</button>
        <button type="button" class="app-confirm__button app-confirm__button--danger" data-confirm-accept>Confirmar</button>
      </div>
    </div>
  `

  document.body.appendChild(root)

  confirmModalState.root = root
  confirmModalState.panel = root.querySelector(".app-confirm__panel")
  confirmModalState.title = root.querySelector(".app-confirm__title")
  confirmModalState.message = root.querySelector(".app-confirm__message")
  confirmModalState.accept = root.querySelector("[data-confirm-accept]")
  confirmModalState.cancelButtons = Array.from(root.querySelectorAll("[data-confirm-cancel]"))

  confirmModalState.accept.addEventListener("click", () => closeConfirmModal(true))
  confirmModalState.cancelButtons.forEach((button) => {
    button.addEventListener("click", () => closeConfirmModal(false))
  })

  return confirmModalState
}

const showCustomConfirm = (message, element) => {
  const modal = ensureConfirmModal()
  const copy = confirmCopyFor(message, element)

  if (modal.resolve) closeConfirmModal(false)
  window.clearTimeout(confirmModalState.closeTimer)

  modal.title.textContent = copy.title
  modal.message.textContent = copy.message
  modal.accept.textContent = copy.confirmLabel
  modal.cancelButtons.forEach((button) => {
    button.textContent = copy.cancelLabel
  })

  modal.root.classList.remove("hidden")
  modal.root.setAttribute("aria-hidden", "false")
  document.body.classList.add("app-confirm-open")

  window.requestAnimationFrame(() => {
    modal.root.classList.add("app-confirm--open")
    modal.panel.focus()
  })

  confirmModalState.restoreFocusTo = document.activeElement

  return new Promise((resolve) => {
    confirmModalState.resolve = resolve
    confirmModalState.keydownHandler = (event) => {
      if (event.key === "Escape") closeConfirmModal(false)
    }

    document.addEventListener("keydown", confirmModalState.keydownHandler)
  })
}

export const installTurboConfirm = () => {
  const Turbo = window.Turbo
  if (!Turbo) return

  if (typeof Turbo.setConfirmMethod === "function") {
    Turbo.setConfirmMethod(showCustomConfirm)
  }

  if (Turbo.config?.forms) {
    Turbo.config.forms.confirm = showCustomConfirm
  }
}

export const cleanupTurboConfirm = () => {
  if (confirmModalState.resolve) closeConfirmModal(false)
  if (confirmModalState.root && !document.body.contains(confirmModalState.root)) {
    resetConfirmModalState()
  }
}
