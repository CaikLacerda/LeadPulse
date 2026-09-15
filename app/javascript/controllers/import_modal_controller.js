import BaseModalController from "controllers/base/modal_controller"

export default class extends BaseModalController {
  static targets = [
    "modal",
    "panel",
    "dropzone",
    "fileInput",
    "label",
    "helper",
    "submit",
    "cadastralRadio",
    "supplierRadio",
    "modalPanel",
    "cadastralCard",
    "supplierCard",
    "separatorInput",
    "fileSelected",
    "fileName",
    "fileMeta",
    "previewSection",
    "previewMeta",
    "previewState",
    "previewSummary",
    "previewMetadataSection",
    "previewMetadata",
    "previewColumnsSection",
    "previewColumns",
    "previewSamplesSection",
    "previewTableHead",
    "previewTableBody",
    "previewInvalidsSection",
    "previewInvalids",
  ]

  static values = {
    defaultLabel: String,
    selectedLabelTemplate: String,
    cadastralHelper: String,
    supplierHelper: String,
    cadastralSubmitLabel: String,
    supplierSubmitLabel: String,
    previewUrl: String,
    previewLoadingLabel: String,
    previewGenericErrorLabel: String,
    previewEmptyLabel: String,
    previewReadyLabel: String,
    previewBlockedLabel: String,
    previewTotalLabel: String,
    previewValidLabel: String,
    previewInvalidLabel: String,
    previewImportStatusLabel: String,
    previewNoInvalidRowsLabel: String,
  }

  connect() {
    super.connect()
    this.previewAbortController = null
    this.previewRequestId = 0
    this.previewRefreshTimeout = null
    this.previewAllowed = false
    this.previewLoading = false
    this.updateSubmitState(this.selectedFile)
    this.updateWorkflowState()
  }

  disconnect() {
    this.abortPreviewRequest()
    clearTimeout(this.previewRefreshTimeout)
  }

  pickFile(event) {
    event?.preventDefault()
    event?.stopPropagation()

    if (event?.type === "keydown" && !["Enter", " "].includes(event.key)) return

    if (!this.hasFileInputTarget) return

    if (typeof this.fileInputTarget.showPicker === "function") {
      this.fileInputTarget.showPicker()
      return
    }

    this.fileInputTarget.click()
  }

  fileChanged() {
    this.showFile(this.selectedFile)
  }

  dragOver(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-blue-500", "bg-blue-50")
  }

  dragLeave() {
    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-blue-500", "bg-blue-50")

    const droppedFile = event.dataTransfer?.files?.[0]
    if (!droppedFile) return

    const dataTransfer = new DataTransfer()
    dataTransfer.items.add(droppedFile)
    this.fileInputTarget.files = dataTransfer.files
    this.showFile(droppedFile)
  }

  workflowChanged() {
    this.updateWorkflowState()
    this.schedulePreviewRefresh()
  }

  separatorChanged() {
    this.schedulePreviewRefresh()
  }

  get selectedFile() {
    return this.fileInputTarget.files?.[0] || null
  }

  showFile(file) {
    if (!file) {
      this.labelTarget.textContent = this.defaultLabelValue
      this.hideSelectedFile()
      this.dropzoneTarget.classList.remove("border-green-400", "bg-green-50", "bg-blue-50")
      this.dropzoneTarget.classList.add("border-blue-300")
      this.resetPreview()
      this.updateSubmitState(null)
      return
    }

    this.labelTarget.textContent = this.defaultLabelValue
    this.fileNameTarget.textContent = file.name
    this.fileMetaTarget.textContent = this.formatFileMeta(file)
    this.fileSelectedTarget.classList.remove("hidden")
    this.dropzoneTarget.classList.remove("border-green-400", "bg-green-50", "bg-blue-50")
    this.dropzoneTarget.classList.add("border-blue-300")
    this.schedulePreviewRefresh()
    this.updateSubmitState(file)
  }

  removeFile(event) {
    event.preventDefault()
    event.stopPropagation()
    this.fileInputTarget.value = ""
    this.showFile(null)
  }

  hideSelectedFile() {
    if (!this.hasFileSelectedTarget) return

    this.fileSelectedTarget.classList.add("hidden")
    if (this.hasFileNameTarget) this.fileNameTarget.textContent = ""
    if (this.hasFileMetaTarget) this.fileMetaTarget.textContent = ""
  }

  formatFileSize(bytes) {
    const size = Number(bytes || 0)
    if (size < 1024) return `${size} B`
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(1).replace(".0", "")} KB`
    return `${(size / (1024 * 1024)).toFixed(1).replace(".0", "")} MB`
  }

  formatFileMeta(file) {
    const extension = file?.name?.split(".").pop()?.toLocaleUpperCase("pt-BR") || "ARQUIVO"
    return `${this.formatFileSize(file?.size)} • ${extension}`
  }

  updateSubmitState(file) {
    const hasFile = Boolean(file)
    const enabled = hasFile && this.previewAllowed && !this.previewLoading
    this.submitTarget.disabled = !enabled
    this.submitTarget.classList.toggle("workspace-button--accent", enabled)
    this.submitTarget.classList.toggle("workspace-button--disabled", !enabled)
  }

  updateWorkflowState() {
    const supplierWorkflowSelected = this.supplierRadioTarget.checked

    this.helperTarget.textContent = supplierWorkflowSelected ? this.supplierHelperValue : this.cadastralHelperValue
    this.submitTarget.value = supplierWorkflowSelected ? this.supplierSubmitLabelValue : this.cadastralSubmitLabelValue

    this.modalPanelTarget.classList.toggle("workspace-modal--orange", supplierWorkflowSelected)
    this.modalPanelTarget.classList.toggle("workspace-modal--blue", !supplierWorkflowSelected)
    this.cadastralCardTarget.classList.toggle("workspace-choice--selected-blue", !supplierWorkflowSelected)
    this.supplierCardTarget.classList.toggle("workspace-choice--selected-orange", supplierWorkflowSelected)
  }

  schedulePreviewRefresh() {
    if (!this.selectedFile) {
      this.resetPreview()
      this.updateSubmitState(null)
      return
    }

    clearTimeout(this.previewRefreshTimeout)
    this.previewRefreshTimeout = setTimeout(() => this.refreshPreview(), 220)
  }

  async refreshPreview() {
    if (!this.selectedFile || !this.hasPreviewUrlValue) {
      this.resetPreview()
      this.updateSubmitState(this.selectedFile)
      return
    }

    this.abortPreviewRequest()
    this.previewLoading = true
    this.previewAllowed = false
    this.showPreviewLoading()
    this.updateSubmitState(this.selectedFile)

    const requestId = ++this.previewRequestId
    const formData = new FormData()
    formData.append("file", this.selectedFile)
    formData.append("separator", this.separatorInputTarget.value || ",")
    formData.append("workflow_kind", this.currentWorkflowKind)

    this.previewAbortController = new AbortController()

    try {
      const response = await fetch(this.previewUrlValue, {
        method: "POST",
        body: formData,
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken,
        },
        signal: this.previewAbortController.signal,
      })

      const payload = await response.json()
      if (requestId !== this.previewRequestId) return

      if (!response.ok || payload.success === false) {
        this.previewLoading = false
        this.previewAllowed = false
        this.renderPreviewError(payload.error_message || this.previewGenericErrorLabelValue)
        this.updateSubmitState(this.selectedFile)
        return
      }

      this.previewLoading = false
      const preview = payload?.preview || {}

      if (this.shouldUseSupplierWorkflow(preview)) {
        this.supplierRadioTarget.checked = true
        this.cadastralRadioTarget.checked = false
        this.updateWorkflowState()
        this.schedulePreviewRefresh()
        return
      }

      this.previewAllowed = Boolean(preview.import_allowed)
      this.renderPreview(preview)
      this.updateSubmitState(this.selectedFile)
    } catch (error) {
      if (error.name === "AbortError") return

      console.error("LeadPulse import preview failed", error)
      this.previewLoading = false
      this.previewAllowed = false
      this.renderPreviewError(this.previewGenericErrorLabelValue)
      this.updateSubmitState(this.selectedFile)
    }
  }

  renderPreview(preview) {
    this.previewSectionTarget.classList.remove("hidden")
    this.previewMetaTarget.textContent = preview.file_name || ""
    this.renderPreviewSummary(preview)
    this.renderPreviewChips(this.previewColumnsSectionTarget, this.previewColumnsTarget, preview.columns || [])
    this.renderPreviewMetadata(preview.metadata_fields || [])
    this.renderPreviewSamples(preview)
    this.renderPreviewInvalids(preview)

    const stateMessage = preview.import_allowed
      ? this.previewReadyLabelValue
      : preview.warnings?.[0] || this.previewBlockedLabelValue

    this.setPreviewState(preview.import_allowed ? "success" : "warning", stateMessage)
  }

  shouldUseSupplierWorkflow(preview) {
    if (this.supplierRadioTarget.checked) return false

    const columns = this.asArray(preview?.columns).map((column) =>
      String(this.previewItemValue(column) || "").toLocaleLowerCase("pt-BR")
    )
    const hasSegment = columns.some((column) => column.includes("segmento"))
    const hasDiscoveryOrigin = columns.some((column) =>
      ["código da busca", "região", "link do google maps", "fontes consultadas"].includes(column)
    )
    return hasSegment && hasDiscoveryOrigin
  }

  renderPreviewSummary(preview) {
    const statusLabel = preview.import_allowed ? this.previewReadyLabelValue : this.previewBlockedLabelValue
    const items = [
      [this.previewTotalLabelValue, preview.total_rows],
      [this.previewValidLabelValue, preview.valid_rows],
      [this.previewInvalidLabelValue, preview.invalid_rows],
      [this.previewImportStatusLabelValue, statusLabel],
    ]

    this.previewSummaryTarget.innerHTML = items
      .map(
        ([label, value]) => `
          <div class="import-preview__metric">
            <p class="import-preview__metric-label">${this.escapeHtml(label)}</p>
            <p class="import-preview__metric-value">${this.escapeHtml(String(value))}</p>
          </div>
        `
      )
      .join("")
    this.previewSummaryTarget.classList.remove("hidden")
  }

  renderPreviewMetadata(fields) {
    const items = this.asArray(fields)

    if (!items.length) {
      this.previewMetadataSectionTarget.classList.add("hidden")
      this.previewMetadataTarget.innerHTML = ""
      return
    }

    this.previewMetadataTarget.innerHTML = items
      .map(
        (field) => `
          <div class="import-preview__chip">
            <span class="import-preview__chip-label">${this.escapeHtml(this.previewItemLabel(field))}:</span>
            <span>${this.escapeHtml(this.previewItemValue(field))}</span>
          </div>
        `
      )
      .join("")
    this.previewMetadataSectionTarget.classList.remove("hidden")
  }

  renderPreviewChips(sectionTarget, contentTarget, items) {
    const normalizedItems = this.asArray(items)

    if (!normalizedItems.length) {
      sectionTarget.classList.add("hidden")
      contentTarget.innerHTML = ""
      return
    }

    contentTarget.innerHTML = normalizedItems
      .map((item) => `<span class="import-preview__chip">${this.escapeHtml(this.previewItemValue(item))}</span>`)
      .join("")
    sectionTarget.classList.remove("hidden")
  }

  renderPreviewSamples(preview) {
    const headers = this.asArray(preview.sample_headers).map((header) => ({
      label: header?.label || header?.key || String(header || ""),
      key: header?.key || header?.label || String(header || ""),
    }))
    const rows = this.asArray(preview.sample_rows)

    if (!headers.length || !rows.length) {
      this.previewSamplesSectionTarget.classList.add("hidden")
      this.previewTableHeadTarget.innerHTML = ""
      this.previewTableBodyTarget.innerHTML = ""
      return
    }

    this.previewTableHeadTarget.innerHTML = `
      <tr>
        <th>#</th>
        ${headers.map((header) => `<th>${this.escapeHtml(header.label)}</th>`).join("")}
      </tr>
    `

    this.previewTableBodyTarget.innerHTML = rows
      .map((row) => {
        const cells = this.asArray(row?.cells)
        const values = cells.length
          ? cells.map((cell) => cell?.value ?? cell)
          : headers.map((header) => row?.[header.key])

        return `
          <tr>
            <td>${this.escapeHtml(String(row?.row_number || "—"))}</td>
            ${values.map((value) => `<td>${this.escapeHtml(this.previewCellValue(value))}</td>`).join("")}
          </tr>
        `
      })
      .join("")

    this.previewSamplesSectionTarget.classList.remove("hidden")
  }

  renderPreviewInvalids(preview) {
    const rows = this.asArray(preview.invalid_rows_preview)

    if (!rows.length) {
      this.previewInvalidsTarget.innerHTML = ""
      this.previewInvalidsSectionTarget.classList.add("hidden")
      return
    }

    this.previewInvalidsTarget.innerHTML = rows
      .map((row) => {
        const errors = this.asArray(row?.errors)
        return `
          <div class="import-preview__invalid-item">
            <p class="import-preview__invalid-title">Linha ${this.escapeHtml(String(row?.row_number || "—"))}</p>
            <p class="import-preview__invalid-errors">${this.escapeHtml(errors.join(", "))}</p>
            ${row?.summary ? `<p class="import-preview__invalid-summary">${this.escapeHtml(row.summary)}</p>` : ""}
          </div>
        `
      })
      .join("")
    this.previewInvalidsSectionTarget.classList.remove("hidden")
  }

  showPreviewLoading() {
    this.previewSectionTarget.classList.remove("hidden")
    this.previewMetaTarget.textContent = this.selectedFile?.name || ""
    this.previewSummaryTarget.classList.add("hidden")
    this.previewMetadataSectionTarget.classList.add("hidden")
    this.previewColumnsSectionTarget.classList.add("hidden")
    this.previewSamplesSectionTarget.classList.add("hidden")
    this.previewInvalidsSectionTarget.classList.add("hidden")
    this.previewSummaryTarget.innerHTML = ""
    this.previewMetadataTarget.innerHTML = ""
    this.previewColumnsTarget.innerHTML = ""
    this.previewTableHeadTarget.innerHTML = ""
    this.previewTableBodyTarget.innerHTML = ""
    this.previewInvalidsTarget.innerHTML = ""
    this.setPreviewState("loading", this.previewLoadingLabelValue)
  }

  renderPreviewError(message) {
    this.previewSectionTarget.classList.remove("hidden")
    this.previewMetaTarget.textContent = this.selectedFile?.name || ""
    this.previewSummaryTarget.classList.add("hidden")
    this.previewMetadataSectionTarget.classList.add("hidden")
    this.previewColumnsSectionTarget.classList.add("hidden")
    this.previewSamplesSectionTarget.classList.add("hidden")
    this.previewInvalidsSectionTarget.classList.add("hidden")
    this.previewSummaryTarget.innerHTML = ""
    this.previewMetadataTarget.innerHTML = ""
    this.previewColumnsTarget.innerHTML = ""
    this.previewTableHeadTarget.innerHTML = ""
    this.previewTableBodyTarget.innerHTML = ""
    this.previewInvalidsTarget.innerHTML = ""
    this.setPreviewState("error", message)
  }

  resetPreview() {
    this.abortPreviewRequest()
    this.previewLoading = false
    this.previewAllowed = false

    if (this.hasPreviewSectionTarget) {
      this.previewSectionTarget.classList.remove("hidden")
    }

    if (this.hasPreviewMetaTarget) this.previewMetaTarget.textContent = ""
    if (this.hasPreviewStateTarget) {
      this.previewStateTarget.textContent = this.previewEmptyLabelValue
      this.previewStateTarget.className = "import-preview__state import-preview__state--empty"
    }
    if (this.hasPreviewSummaryTarget) {
      this.previewSummaryTarget.innerHTML = ""
      this.previewSummaryTarget.classList.add("hidden")
    }
    if (this.hasPreviewMetadataSectionTarget) this.previewMetadataSectionTarget.classList.add("hidden")
    if (this.hasPreviewMetadataTarget) this.previewMetadataTarget.innerHTML = ""
    if (this.hasPreviewColumnsSectionTarget) this.previewColumnsSectionTarget.classList.add("hidden")
    if (this.hasPreviewColumnsTarget) this.previewColumnsTarget.innerHTML = ""
    if (this.hasPreviewSamplesSectionTarget) this.previewSamplesSectionTarget.classList.add("hidden")
    if (this.hasPreviewTableHeadTarget) this.previewTableHeadTarget.innerHTML = ""
    if (this.hasPreviewTableBodyTarget) this.previewTableBodyTarget.innerHTML = ""
    if (this.hasPreviewInvalidsSectionTarget) this.previewInvalidsSectionTarget.classList.add("hidden")
    if (this.hasPreviewInvalidsTarget) this.previewInvalidsTarget.innerHTML = ""
  }

  setPreviewState(kind, message) {
    this.previewStateTarget.textContent = message
    this.previewStateTarget.className = `import-preview__state import-preview__state--${kind}`
  }

  abortPreviewRequest() {
    this.previewAbortController?.abort()
    this.previewAbortController = null
  }

  get currentWorkflowKind() {
    return this.supplierRadioTarget.checked ? this.supplierRadioTarget.value : this.cadastralRadioTarget.value
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  asArray(value) {
    if (Array.isArray(value)) return value
    if (value === null || value === undefined || value === "") return []
    return [value]
  }

  previewItemLabel(item) {
    if (item && typeof item === "object") return item.label || item.key || "Campo"
    return "Campo"
  }

  previewItemValue(item) {
    if (item && typeof item === "object") {
      const value = item.value ?? item.label ?? item.key ?? item
      return value && typeof value === "object" ? JSON.stringify(value) : value
    }

    return item
  }

  previewCellValue(value) {
    const displayValue = this.previewItemValue(value)
    return displayValue === null || displayValue === undefined || displayValue === "" ? "—" : displayValue
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }
}
