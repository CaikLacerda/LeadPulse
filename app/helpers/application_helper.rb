module ApplicationHelper
  WORKSPACE_TIME_ZONE = "America/Sao_Paulo".freeze

  WORKSPACE_TUTORIAL_STEP_CONFIG = {
    home: [
      { key: :actions, selector: '[data-tutorial-id="home-actions"]' },
      { key: :metrics, selector: '[data-tutorial-id="home-metrics"]' },
      { key: :batches, selector: '[data-tutorial-id="home-batches"]' },
      { key: :integrations, selector: '[data-tutorial-id="home-integrations"]' }
    ],
    supplier_discovery_searches: [
      { key: :create, selector: '[data-tutorial-id="search-create"]' },
      { key: :filters, selector: '[data-tutorial-id="search-filters"]' },
      { key: :results, selector: '[data-tutorial-id="search-results"]' }
    ],
    supplier_imports: [
      { key: :create, selector: '[data-tutorial-id="imports-create"]' },
      { key: :filters, selector: '[data-tutorial-id="imports-filters"]' },
      { key: :results, selector: '[data-tutorial-id="imports-results"]' }
    ],
    platform_settings_company: [
      { key: :form, selector: '[data-tutorial-id="company-fields"]' },
      { key: :account, selector: '[data-tutorial-id="company-account"]' },
      { key: :submit, selector: '[data-tutorial-id="company-submit"]' }
    ],
    platform_settings_twilio: [
      { key: :tabs, selector: '[data-tutorial-id="settings-tabs"]' },
      { key: :form, selector: '[data-tutorial-id="twilio-credentials"]' },
      { key: :numbers, selector: '[data-tutorial-id="twilio-numbers"]' },
      { key: :submit, selector: '[data-tutorial-id="twilio-submit"]' }
    ],
    platform_settings_openai: [
      { key: :tabs, selector: '[data-tutorial-id="settings-tabs"]' },
      { key: :api_key, selector: '[data-tutorial-id="openai-api-key"]' },
      { key: :profile, selector: '[data-tutorial-id="openai-profile"]' },
      { key: :submit, selector: '[data-tutorial-id="openai-submit"]' }
    ],
    platform_settings_api_token: [
      { key: :tabs, selector: '[data-tutorial-id="settings-tabs"]' },
      { key: :status, selector: '[data-tutorial-id="token-status"]' },
      { key: :generate, selector: '[data-tutorial-id="token-submit"]' }
    ],
    platform_settings_lgpd: [
      { key: :policy, selector: '[data-tutorial-id="lgpd-policy"]' },
      { key: :form, selector: '[data-tutorial-id="lgpd-form"]' },
      { key: :principles, selector: '[data-tutorial-id="lgpd-principles"]' },
      { key: :save, selector: '[data-tutorial-id="lgpd-save"]' }
    ],
    validation_audits: [
      { key: :filters, selector: '[data-tutorial-id="audit-filters"]' },
      { key: :results, selector: '[data-tutorial-id="audit-results"]' },
      { key: :transcripts, selector: '[data-tutorial-id="audit-transcripts"]' }
    ]
  }.freeze

  # Tom de cada status conhecido. O rótulo vem do I18n; o tom define a cor do StatusBadge.
  STATUS_TONES = {
    success: %w[
      concluido completed complete confirmed confirmed_by_call confirmed_by_whatsapp confirmed_by_email
      validated qualified_supplier success resolved
    ],
    info: %w[
      processando processing in_progress in-progress accepted answered call_answered queued
      whatsapp_sent email_sent waiting_whatsapp_reply waiting_email_reply
    ],
    warning: %w[inconclusive inconclusive_call not_answered call_not_answered],
    danger: %w[
      erro error failed validation_failed invalid_phone wrong_company does_not_supply_segment
      not_interested privacy_refusal cnpj_not_found rejected rejected_by_call rejected_by_whatsapp rejected_by_email
    ],
    neutral: %w[pendente pending awaiting_submission open cancelled canceled ready_for_call ready_for_retry_call]
  }.each_with_object({}) { |(tone, statuses), map| statuses.each { |status| map[status] = tone } }.freeze

  PULSING_STATUSES = %w[processando processing in_progress in-progress].freeze

  # Status remotos em inglês que têm equivalente local traduzido em shared.statuses.
  LOCAL_STATUS_ALIASES = {
    "pending" => "pendente",
    "processing" => "processando",
    "in_progress" => "processando",
    "in-progress" => "processando",
    "completed" => "concluido",
    "complete" => "concluido",
    "error" => "erro",
    "failed" => "erro"
  }.freeze

  # Abas das páginas de configuração: Integrações e LGPD têm abas; Empresa não.
  SETTINGS_NAVS = { integrations: "platform_settings/nav", lgpd: "platform_settings/lgpd_nav" }.freeze

  WORKSPACE_BUTTON_VARIANTS = {
    primary: "workspace-button--primary",
    secondary: "workspace-button--secondary",
    ghost: "workspace-button--ghost",
    danger: "workspace-button--danger",
    accent: "workspace-button--accent",
    disabled: "workspace-button--disabled"
  }.freeze

  WORKSPACE_ICON_CLASSES = {
    home: "fa-house",
    search: "fa-magnifying-glass",
    validation: "fa-layer-group",
    commercial: "fa-users",
    handshake: "fa-handshake",
    audit: "fa-list-check",
    shield: "fa-shield-halved",
    code: "fa-code",
    chart: "fa-chart-column",
    analytics: "fa-chart-line",
    team: "fa-user-group",
    integrations: "fa-plug",
    database: "fa-database",
    clock: "fa-clock",
    bell: "fa-bell",
    user: "fa-user",
    settings: "fa-gear",
    plus: "fa-plus",
    filter: "fa-filter",
    map_pin: "fa-location-dot",
    building: "fa-building",
    message: "fa-comment-dots",
    key: "fa-key",
    download: "fa-download",
    export: "fa-file-arrow-down",
    ellipsis: "fa-ellipsis",
    chevron_down: "fa-chevron-down",
    chevron_right: "fa-chevron-right",
    external: "fa-arrow-up-right-from-square",
    help: "fa-circle-question",
    warning: "fa-triangle-exclamation",
    info: "fa-circle-info",
    check: "fa-circle-check",
    play: "fa-play",
    refresh: "fa-arrows-rotate",
    trash: "fa-trash-can",
    upload: "fa-arrow-up-from-bracket",
    file: "fa-file-lines"
  }.freeze

  def workspace_page(max_width: "max-w-[90rem]", classes: nil, content_classes: nil, &block)
    content_tag(:div, class: workspace_class_names("workspace-page", classes)) do
      content_tag(:div, class: workspace_class_names("workspace-content", max_width, content_classes)) do
        capture(&block)
      end
    end
  end

  # Cabeçalho padrão das páginas: título (+ status), descrição curta e ações à direita.
  # A seção da página aparece no breadcrumb da topbar.
  def workspace_page_header(title:, description: nil, status: nil, meta: nil, actions: nil, actions_data: {}, &block)
    action_content = block_given? ? capture(&block) : actions

    content_tag(:header, class: "workspace-page-header") do
      safe_join([
        content_tag(:div, class: "workspace-page-header__body") do
          safe_join([
            content_tag(:div, class: "workspace-page-header__heading") do
              safe_join([ content_tag(:h1, title, class: "workspace-page-title"), status ].compact)
            end,
            (content_tag(:p, description, class: "workspace-page-description") if description.present?),
            (content_tag(:div, meta, class: "workspace-page-meta") if meta.present?)
          ].compact)
        end,
        (content_tag(:div, action_content, class: "workspace-page-actions", data: actions_data) if action_content.present?)
      ].compact)
    end
  end

  # Painel com cabeçalho (título, contagem e ações) e corpo. `icon` é ignorado: ícones decorativos saíram dos painéis.
  def portlet_form(title, actions = [], options = {}, &block)
    body_class = options.delete(:body_class)
    title_class = options.delete(:title_class)
    count = options.delete(:count)
    options.delete(:icon)
    html_options = options.dup
    html_options[:class] = workspace_class_names("workspace-portlet", html_options[:class])

    content_tag(:section, html_options) do
      safe_join([
        (workspace_panel_header(title:, count:, actions:, title_class:) if title.present?),
        content_tag(:div, class: workspace_class_names("workspace-portlet-body", body_class)) do
          capture(&block)
        end
      ].compact)
    end
  end

  def workspace_panel_header(title:, count: nil, actions: nil, title_class: nil)
    content_tag(:div, class: "workspace-portlet-title") do
      content_tag(:div, class: "caption") do
        safe_join([
          content_tag(:div, class: "workspace-portlet-title__heading") do
            safe_join([
              content_tag(:h2, title, class: workspace_class_names("subtitle", title_class)),
              (content_tag(:span, count, class: "workspace-portlet-title__count") if count.present?)
            ].compact)
          end,
          actions_span(safe_join(Array(actions)), class: "workspace-portlet-title__actions")
        ].compact)
      end
    end
  end

  # Barra de filtros sem caixa, posicionada logo acima da tabela.
  def portlet_search(options = {}, &block)
    html_options = options.dup
    html_options[:class] = workspace_class_names("workspace-filters", html_options[:class])

    content_tag(:div, html_options) do
      capture(&block)
    end
  end

  def actions_span(content, options = {})
    return if content.blank?

    content_tag(:div, content, options)
  end

  def workspace_button_class(variant = :secondary, classes = nil, size: nil)
    variant_class = WORKSPACE_BUTTON_VARIANTS.fetch(variant.to_sym, WORKSPACE_BUTTON_VARIANTS[:secondary])
    workspace_class_names("workspace-button", variant_class, ("workspace-button--#{size}" if size.present?), classes)
  end

  def workspace_submit_class(variant = :primary, classes = nil, size: nil)
    workspace_button_class(variant, classes, size:)
  end

  # Aceita as duas formas do link_to: (texto, caminho) ou (caminho) { conteúdo }.
  def workspace_link_button(text, path = nil, variant: :secondary, size: nil, classes: nil, **options, &block)
    path, text = text, nil if block_given? && path.nil?
    options[:class] = workspace_button_class(variant, workspace_class_names(options[:class], classes), size:)

    link_to(path, options) do
      block_given? ? capture(&block) : text
    end
  end

  def workspace_button_tag(text = nil, variant: :primary, size: nil, classes: nil, **options, &block)
    options[:class] = workspace_button_class(variant, workspace_class_names(options[:class], classes), size:)

    button_tag(options) do
      block_given? ? capture(&block) : text
    end
  end

  def workspace_code_tag(value, path = nil)
    return link_to(value, path, class: "workspace-compact-code") if path.present?

    content_tag(:span, value, class: "workspace-compact-code")
  end

  def workspace_datetime_cell(value)
    return content_tag(:span, "—", class: "workspace-table__empty-dash") if value.blank?

    content_tag(:span, class: "workspace-datetime") do
      safe_join([
        workspace_date(value),
        content_tag(:span, workspace_time(value), class: "workspace-datetime__time")
      ])
    end
  end

  def workspace_empty_table_row(colspan:, message:, hint: nil, &block)
    content_tag(:tr) do
      content_tag(:td, colspan:) do
        workspace_empty_state(message:, hint:, &block)
      end
    end
  end

  def workspace_empty_state(message:, hint: nil, &block)
    content_tag(:div, class: "workspace-empty-state") do
      safe_join([
        content_tag(:p, message, class: "workspace-empty-state__title"),
        (content_tag(:p, hint, class: "workspace-empty-state__hint") if hint.present?),
        (content_tag(:div, capture(&block), class: "workspace-empty-state__actions") if block_given?)
      ].compact)
    end
  end

  # Faixa única de métricas; cada `workspace_metric_card` é uma célula.
  def workspace_metrics(classes: nil, data: {}, &block)
    content_tag(:div, class: workspace_class_names("workspace-metrics", classes), data: data) do
      content_tag(:div, capture(&block), class: "workspace-metrics__grid")
    end
  end

  def workspace_metric_card(label:, value:, description: nil, value_class: nil, icon: nil, path: nil)
    content = safe_join([
      content_tag(:p, label, class: "workspace-metric-card__label"),
      content_tag(:p, value, class: workspace_class_names("workspace-metric-card__value", value_class)),
      (content_tag(:p, description, class: "workspace-metric-card__description", title: description) if description.present?)
    ].compact)

    return link_to(content, path, class: "workspace-metric-card workspace-metric-card--link") if path.present?

    content_tag(:div, content, class: "workspace-metric-card")
  end

  def workspace_icon(name, classes: nil)
    icon_class = WORKSPACE_ICON_CLASSES[name.to_sym]
    return "".html_safe if icon_class.blank?

    content_tag(
      :i,
      "",
      class: workspace_class_names("workspace-icon", "fa-solid", icon_class, classes),
      aria: { hidden: true }
    )
  end

  def workspace_notifications
    return [] unless current_user

    @workspace_notifications ||= begin
      items = []
      imports = current_account.supplier_imports
      commercial = current_account.commercial_opportunities

      import_status_counts = imports.group(:status).count
      pending_imports = import_status_counts.fetch(SupplierImport::LOCAL_STATUS_PENDING, 0)
      processing_imports = import_status_counts.fetch(SupplierImport::LOCAL_STATUS_PROCESSING, 0)
      ready_exports = imports.where(result_ready: true).count
      import_errors = import_status_counts.fetch(SupplierImport::LOCAL_STATUS_ERROR, 0)
      pending_commercial = commercial.where(status: CommercialOpportunity::STATUS_PENDING).count

      if pending_imports.positive? && current_membership.can_start_validation?
        items << {
          key: "pending_imports:#{pending_imports}",
          icon: :clock,
          tone: :warning,
          title: "Lotes aguardando início",
          body: "#{pending_imports} lote#{'s' if pending_imports != 1} pronto#{'s' if pending_imports != 1} para iniciar.",
          path: supplier_imports_path(status: SupplierImport::LOCAL_STATUS_PENDING)
        }
      end

      if processing_imports.positive?
        items << {
          key: "processing_imports:#{processing_imports}",
          icon: :validation,
          tone: :info,
          title: "Validação em andamento",
          body: "#{processing_imports} lote#{'s' if processing_imports != 1} sendo processado#{'s' if processing_imports != 1}.",
          path: supplier_imports_path(status: SupplierImport::LOCAL_STATUS_PROCESSING)
        }
      end

      if ready_exports.positive? && current_membership.can_export_data?
        items << {
          key: "ready_exports:#{ready_exports}",
          icon: :database,
          tone: :success,
          title: "Resultados disponíveis",
          body: "#{ready_exports} resultado#{'s' if ready_exports != 1} pronto#{'s' if ready_exports != 1} para exportação.",
          path: supplier_imports_path(status: SupplierImport::LOCAL_STATUS_COMPLETED)
        }
      end

      if pending_commercial.positive? && current_membership.can_start_validation?
        items << {
          key: "pending_commercial:#{pending_commercial}",
          icon: :commercial,
          tone: :commercial,
          title: "Retornos comerciais pendentes",
          body: "#{pending_commercial} fornecedor#{'es' if pending_commercial != 1} aguardando coleta comercial.",
          path: commercial_opportunities_path(status: CommercialOpportunity::STATUS_PENDING)
        }
      end

      if import_errors.positive?
        items << {
          key: "import_errors:#{import_errors}",
          icon: :bell,
          tone: :danger,
          title: "Lotes com erro",
          body: "#{import_errors} lote#{'s' if import_errors != 1} precisa#{'m' if import_errors != 1} de atenção.",
          path: supplier_imports_path(status: SupplierImport::LOCAL_STATUS_ERROR)
        }
      end

      read_keys = current_user.workspace_notification_reads
        .where(notification_key: items.pluck(:key))
        .pluck(:notification_key)

      items.map { |item| item.merge(read: read_keys.include?(item[:key])) }
    end
  end

  def workspace_definition_row(label:, value: nil, &block)
    content_tag(:div, class: "workspace-definition-row") do
      safe_join([
        content_tag(:dt, label, class: "workspace-definition-row__label"),
        content_tag(:dd, block_given? ? capture(&block) : value, class: "workspace-definition-row__value")
      ])
    end
  end

  def settings_panel(classes: nil, &block)
    content_tag(:section, class: workspace_class_names("settings-panel", classes)) do
      capture(&block)
    end
  end

  # Seção de formulário: título e descrição à esquerda, campos à direita.
  def settings_section(title:, description: nil, data: {}, &block)
    content_tag(:div, class: "settings-section", data: data) do
      safe_join([
        content_tag(:div) do
          safe_join([
            content_tag(:h2, title, class: "settings-section__title"),
            (content_tag(:p, description, class: "settings-section__description") if description.present?)
          ].compact)
        end,
        content_tag(:div, capture(&block), class: "min-w-0")
      ])
    end
  end

  def settings_feedback_messages(standalone: false)
    notice = flash[:notice].presence || flash.now[:notice].presence
    alert = flash.now[:alert].presence || flash[:alert].presence

    safe_join([
      (settings_feedback_tag(notice, variant: :notice, standalone:) if notice.present?),
      (settings_feedback_tag(alert, variant: :alert, standalone:) if alert.present?)
    ].compact)
  end

  def settings_feedback_tag(message, variant:, standalone: false)
    content_tag(:div, message, class: workspace_class_names("settings-feedback", "settings-feedback--#{variant}", ("settings-feedback--standalone" if standalone)), role: (variant == :alert ? "alert" : "status"))
  end

  def platform_settings_page(title:, description: nil, max_width: "max-w-5xl", tutorial_key: nil, nav: :integrations, &block)
    workspace_page(max_width:) do
      turbo_frame_tag "platform_settings_content" do
        safe_join([
          workspace_page_header(title:, description:),
          (render(SETTINGS_NAVS.fetch(nav)) if SETTINGS_NAVS.key?(nav)),
          capture(&block),
          (render("shared/workspace_tutorial", steps: workspace_tutorial_steps(tutorial_key)) if tutorial_key.present?)
        ].compact)
      end
    end
  end

  def workspace_class_names(*classes)
    classes.flatten.compact.flat_map { |klass| klass.to_s.split(/\s+/) }.reject(&:blank?).uniq.join(" ")
  end

  # StatusBadge: único componente visual de status (ponto + rótulo).
  def status_badge(label, tone: :neutral, pulse: false, title: nil)
    tone = :neutral unless %i[success warning danger info neutral].include?(tone.to_sym)

    content_tag(
      :span,
      class: workspace_class_names("workspace-status", "workspace-status--#{tone}", ("workspace-status--pulse" if pulse)),
      title: title.presence
    ) do
      safe_join([
        content_tag(:span, "", class: "workspace-status__dot", aria: { hidden: true }),
        content_tag(:span, label, class: "workspace-status__label")
      ])
    end
  end

  def workspace_status_tone(status)
    STATUS_TONES.fetch(status.to_s.strip.downcase, :neutral)
  end

  def workspace_status_tag(status)
    normalized = status.to_s.strip.downcase
    status_badge(local_status_label(status), tone: workspace_status_tone(normalized), pulse: PULSING_STATUSES.include?(normalized))
  end

  def local_status_label(status)
    normalized_status = status.to_s.strip
    return I18n.t("shared.statuses.awaiting_submission") if normalized_status.blank?

    key = LOCAL_STATUS_ALIASES.fetch(normalized_status.downcase, normalized_status)
    I18n.t("shared.statuses.#{key}", default: normalized_status.tr("_-", " ").capitalize)
  end

  def translated_remote_batch_status(status)
    case status.to_s.strip.downcase
    when "", nil
      I18n.t("shared.remote_batch_statuses.awaiting_submission")
    when "accepted"
      I18n.t("shared.remote_batch_statuses.accepted")
    when "pending"
      I18n.t("shared.remote_batch_statuses.pending")
    when "queued"
      I18n.t("shared.remote_batch_statuses.queued")
    when "processing", "in_progress", "in-progress"
      I18n.t("shared.remote_batch_statuses.processing")
    when "completed", "complete"
      I18n.t("shared.remote_batch_statuses.completed")
    when "failed", "error"
      I18n.t("shared.remote_batch_statuses.failed")
    when "cancelled", "canceled"
      I18n.t("shared.remote_batch_statuses.cancelled")
    else
      status.to_s.tr("_-", " ").strip.capitalize.presence || I18n.t("shared.remote_batch_statuses.awaiting_submission")
    end
  end

  def pagination_series(current_page, total_pages, window: 1)
    return [] if total_pages <= 1

    pages = [ 1, total_pages ]
    pages.concat(((current_page - window)..(current_page + window)).to_a)
    pages = pages.select { |page| page.between?(1, total_pages) }.uniq.sort

    series = []
    pages.each_with_index do |page, index|
      previous_page = pages[index - 1]
      series << :gap if previous_page && page - previous_page > 1
      series << page
    end
    series
  end

  def audit_action_label(workflow_kind)
    I18n.t(
      "validation_audits.index.actions.#{workflow_kind}",
      default: workflow_kind.to_s.tr("_", " ").capitalize
    )
  end

  def audit_result_label(result_code)
    normalized = result_code.to_s.strip
    return I18n.t("validation_audits.index.results.unknown") if normalized.blank?

    I18n.t("validation_audits.index.results.#{normalized}", default: normalized.tr("_-", " ").capitalize)
  end

  def audit_result_tag(result_code)
    normalized = result_code.to_s.strip
    status_badge(audit_result_label(normalized), tone: workspace_status_tone(normalized), pulse: PULSING_STATUSES.include?(normalized))
  end

  def audit_review_result_options
    AuditReview::RESULT_OPTIONS.map do |result|
      [
        I18n.t("validation_audits.index.results.#{result}", default: result.tr("_-", " ").capitalize),
        result
      ]
    end
  end

  def supplier_import_detail_records(supplier_import)
    records = Array(supplier_import.response_payload["records"])
    records.presence || Array(supplier_import.request_payload["records"])
  end

  def supplier_import_record_name(record)
    record["client_name"].presence ||
      record["company_name"].presence ||
      record["supplier_name"].presence ||
      record["external_id"].presence ||
      "Registro"
  end

  def supplier_import_record_phone(record)
    record["validated_phone"].presence ||
      record["phone_normalized"].presence ||
      record["phone_original"].presence ||
      record["phone"].presence ||
      record["last_phone_dialed"].presence ||
      "-"
  end

  def supplier_import_record_result_code(record)
    supplier_validation = record["supplier_validation"].is_a?(Hash) ? record["supplier_validation"] : {}

    supplier_validation["outcome"].presence ||
      record["business_status"].presence ||
      record["final_status"].presence ||
      record["call_result"].presence ||
      record["call_status"].presence
  end

  def supplier_import_record_attempts(record)
    Array(record["call_attempts"])
  end

  def supplier_import_attempt_duration(attempt)
    duration = attempt["duration_seconds"].presence || attempt["call_duration_seconds"].presence
    return "#{duration.to_f.round(1)} s" if duration.present?

    started_at = ValidationApi::Timestamp.parse(attempt["started_at"])
    finished_at = ValidationApi::Timestamp.parse(attempt["finished_at"])
    return "-" if started_at.blank? || finished_at.blank?

    "#{(finished_at - started_at).round(1)} s"
  end

  def supplier_import_privacy_notice(supplier_import)
    supplier_import.privacy_notice
  end

  def supplier_import_recording_count(supplier_import)
    supplier_import_detail_records(supplier_import).sum do |record|
      supplier_import_record_attempts(record).count { |attempt| attempt["recording_url"].present? }
    end
  end

  def supplier_import_privacy_refusal_count(supplier_import)
    supplier_import_detail_records(supplier_import).count do |record|
      record["privacy_refusal_detected"].present? ||
        supplier_import_record_attempts(record).any? { |attempt| attempt["privacy_refusal_detected"].present? }
    end
  end

  def supplier_import_evidence_anonymized?(supplier_import)
    supplier_import.evidence_anonymized?
  end

  def supplier_import_evidence_expires_at(supplier_import)
    supplier_import.evidence_expires_at
  end

  def workspace_date(value)
    workspace_timestamp(value, format: "%d/%m/%Y")
  end

  def workspace_time(value)
    workspace_timestamp(value, format: "%H:%M")
  end

  def workspace_datetime(value)
    workspace_timestamp(value, format: "%d/%m/%Y %H:%M")
  end

  def workspace_tutorial_steps(page_key)
    step_config = WORKSPACE_TUTORIAL_STEP_CONFIG.fetch(page_key.to_sym, [])

    step_config.map do |step|
      {
        selector: step.fetch(:selector),
        title: I18n.t("shared.tutorial.pages.#{page_key}.steps.#{step[:key]}.title"),
        body: I18n.t("shared.tutorial.pages.#{page_key}.steps.#{step[:key]}.body")
      }
    end
  end

  private

  def parse_workspace_time(value)
    return if value.blank?
    return value if value.respond_to?(:in_time_zone)

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def workspace_timestamp(value, format:)
    return "—" if value.blank?

    I18n.l(value.in_time_zone(WORKSPACE_TIME_ZONE), format: format)
  end
end
