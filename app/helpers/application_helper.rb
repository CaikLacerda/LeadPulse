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
      { key: :tabs, selector: '[data-tutorial-id="settings-tabs"]' },
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

  WORKSPACE_STATUS_VARIANTS = {
    SupplierImport::LOCAL_STATUS_PENDING => "workspace-status--warning",
    SupplierImport::LOCAL_STATUS_PROCESSING => "workspace-status--info",
    SupplierImport::LOCAL_STATUS_COMPLETED => "workspace-status--success",
    SupplierImport::LOCAL_STATUS_ERROR => "workspace-status--danger"
  }.freeze

  AUDIT_RESULT_VARIANTS = {
    "confirmed_by_call" => "workspace-status--success",
    "confirmed_by_whatsapp" => "workspace-status--success",
    "confirmed_by_email" => "workspace-status--success",
    "validated" => "workspace-status--success",
    "qualified_supplier" => "workspace-status--success",
    "success" => "workspace-status--success",
    "inconclusive" => "workspace-status--warning",
    "inconclusive_call" => "workspace-status--warning",
    "not_answered" => "workspace-status--warning",
    "answered" => "workspace-status--info",
    "accepted" => "workspace-status--info",
    "processing" => "workspace-status--info",
    "wrong_company" => "workspace-status--danger",
    "does_not_supply_segment" => "workspace-status--danger",
    "not_interested" => "workspace-status--danger",
    "privacy_refusal" => "workspace-status--danger",
    "validation_failed" => "workspace-status--danger",
    "invalid_phone" => "workspace-status--danger",
    "failed" => "workspace-status--danger",
    "error" => "workspace-status--danger"
  }.freeze

  WORKSPACE_BUTTON_VARIANTS = {
    secondary: "workspace-button--secondary",
    primary: "workspace-button--primary",
    accent: "workspace-button--accent",
    disabled: "workspace-button--disabled"
  }.freeze

  WORKSPACE_ICON_PATHS = {
    home: [ "M3 11.5 12 4l9 7.5", "M5.5 10v10h13V10", "M9.5 20v-6h5v6" ],
    search: [ "M21 21l-4.35-4.35", "M19 11a8 8 0 1 1-16 0 8 8 0 0 1 16 0Z" ],
    validation: [ "m12 3-9 5 9 5 9-5-9-5Z", "m3 12 9 5 9-5", "m3 16 9 5 9-5" ],
    commercial: [ "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z", "M22 21v-2a4 4 0 0 0-3-3.87", "M16 3.13a4 4 0 0 1 0 7.75" ],
    chart: [ "M4 20V10", "M10 20V4", "M16 20v-7", "M22 20H2" ],
    database: [ "M20 5c0 1.66-3.58 3-8 3S4 6.66 4 5s3.58-3 8-3 8 1.34 8 3Z", "M4 5v6c0 1.66 3.58 3 8 3s8-1.34 8-3V5", "M4 11v6c0 1.66 3.58 3 8 3s8-1.34 8-3v-6" ],
    clock: [ "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20Z", "M12 6v6l4 2" ],
    bell: [ "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9", "M10 21h4" ],
    user: [ "M20 21a8 8 0 0 0-16 0", "M12 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10Z" ],
    settings: [ "M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z", "M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.12 3.67-.09-.03a1.7 1.7 0 0 0-1.84.27l-.75.43a1.7 1.7 0 0 0-.82 1.7V23H9.82v-.1A1.7 1.7 0 0 0 9 21.28l-.75-.43a1.7 1.7 0 0 0-1.84-.27l-.09.03-2.12-3.67.06-.06A1.7 1.7 0 0 0 4.6 15v-.86a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.12-3.67.09.03a1.7 1.7 0 0 0 1.84-.27L9 7.86a1.7 1.7 0 0 0 .82-1.7V6h4.36v.16a1.7 1.7 0 0 0 .82 1.7l.75.43a1.7 1.7 0 0 0 1.84.27l.09-.03 2.12 3.67-.06.06a1.7 1.7 0 0 0-.34 1.88V15Z" ],
    plus: [ "M12 5v14", "M5 12h14", "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20Z" ],
    filter: [ "M4 5h16l-6.5 7.25V19l-3 1v-7.75L4 5Z" ],
    map_pin: [ "M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z", "M12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z" ],
    building: [ "M4 22V7l8-4v19", "M12 9h8v13", "M2 22h20", "M7 10h2M7 14h2M7 18h2M15 13h2M15 17h2" ],
    message: [ "M21 15a4 4 0 0 1-4 4H8l-5 3 1.5-4A8 8 0 1 1 21 15Z", "M8 11h.01M12 11h.01M16 11h.01" ],
    key: [ "M15 7a5 5 0 1 1-3.9 4.88L3 20v2h3l2-2h2l2-2v-2.1A5 5 0 0 1 15 7Z" ]
  }.freeze

  def workspace_page(max_width: "max-w-7xl", classes: nil, content_classes: nil, &block)
    content_tag(:div, class: workspace_class_names("workspace-page", classes)) do
      content_tag(:div, class: workspace_class_names("workspace-content mx-auto", max_width, content_classes)) do
        capture(&block)
      end
    end
  end

  def workspace_page_header(kicker:, title:, description: nil, actions: nil, actions_data: {}, &block)
    action_content = block_given? ? capture(&block) : actions

    content_tag(:section, class: "workspace-page-header") do
      safe_join([
        content_tag(:div, class: "workspace-page-header__body") do
          safe_join([
            content_tag(:p, kicker, class: "workspace-page-kicker"),
            content_tag(:h1, title, class: "workspace-page-title"),
            (content_tag(:p, description, class: "workspace-page-description") if description.present?)
          ].compact)
        end,
        (content_tag(:div, action_content, class: "workspace-page-actions", data: actions_data) if action_content.present?)
      ].compact)
    end
  end

  def portlet_form(title, actions = [], options = {}, &block)
    body_class = options.delete(:body_class)
    title_class = options.delete(:title_class)
    icon = options.delete(:icon)
    html_options = options.dup
    html_options[:class] = workspace_class_names("workspace-portlet", html_options[:class])

    content_tag(:section, html_options) do
      safe_join([
        content_tag(:div, class: "workspace-portlet-title") do
          content_tag(:div, class: "caption") do
            safe_join([
              content_tag(:span, class: "workspace-portlet-title__heading") do
                safe_join([
                  (workspace_icon(icon, classes: "workspace-portlet-title__icon") if icon.present?),
                  content_tag(:span, title, class: workspace_class_names("subtitle", title_class))
                ].compact)
              end,
              actions_span(safe_join(Array(actions)), class: "workspace-portlet-title__actions")
            ].compact)
          end
        end,
        content_tag(:div, class: workspace_class_names("workspace-portlet-body form", body_class)) do
          capture(&block)
        end
      ])
    end
  end

  def portlet_search(options = {}, &block)
    html_options = options.dup
    html_options[:class] = workspace_class_names("workspace-portlet workspace-portlet--search", html_options[:class])

    content_tag(:section, html_options) do
      safe_join([
        content_tag(:div, "", class: "workspace-portlet-actions"),
        content_tag(:div, class: "workspace-portlet-body") do
          capture(&block)
        end
      ])
    end
  end

  def actions_span(content, options = {})
    return if content.blank?

    content_tag(:span, content, options)
  end

  def workspace_surface(title:, meta: nil, classes: nil, data: {}, &block)
    content_tag(:section, class: workspace_class_names("workspace-surface", classes), data: data) do
      safe_join([
        workspace_surface_header(title:, meta:),
        capture(&block)
      ])
    end
  end

  def workspace_surface_header(title:, meta: nil)
    content_tag(:div, class: "workspace-surface-header") do
      safe_join([
        content_tag(:p, title, class: "workspace-surface-title"),
        (content_tag(:p, meta, class: "workspace-surface-meta") if meta.present?)
      ].compact)
    end
  end

  def workspace_filter_toolbar(data: {}, classes: nil, &block)
    content_tag(:div, class: workspace_class_names("workspace-toolbar mb-6", classes), data: data) do
      capture(&block)
    end
  end

  def workspace_button_class(variant = :secondary, classes = nil)
    variant_class = WORKSPACE_BUTTON_VARIANTS.fetch(variant.to_sym, WORKSPACE_BUTTON_VARIANTS[:secondary])
    workspace_class_names("workspace-button", variant_class, classes)
  end

  def workspace_submit_class(variant = :primary, classes = nil)
    workspace_button_class(variant, classes)
  end

  def workspace_link_button(text, path, variant: :secondary, classes: nil, **options, &block)
    options[:class] = workspace_button_class(variant, workspace_class_names(options[:class], classes))

    link_to(path, options) do
      block_given? ? capture(&block) : text
    end
  end

  def workspace_button_tag(text = nil, variant: :primary, classes: nil, **options, &block)
    options[:class] = workspace_button_class(variant, workspace_class_names(options[:class], classes))

    button_tag(options) do
      block_given? ? capture(&block) : text
    end
  end

  def workspace_code_tag(value, path = nil)
    return link_to(value, path, class: "workspace-compact-code") if path.present?

    content_tag(:span, value, class: "workspace-compact-code")
  end

  def workspace_datetime_cell(value)
    return content_tag(:div, "-", class: "font-medium text-slate-400") if value.blank?

    safe_join([
      content_tag(:div, workspace_date(value), class: "font-medium text-slate-800"),
      content_tag(:div, workspace_time(value), class: "mt-0.5 text-[11px] text-slate-400")
    ])
  end

  def workspace_empty_table_row(colspan:, message:, &block)
    content_tag(:tr) do
      content_tag(:td, colspan:, class: "px-4 py-12") do
        content_tag(:div, class: "workspace-empty-state") do
          safe_join([
            content_tag(:p, message, class: "text-sm font-medium text-slate-500"),
            (capture(&block) if block_given?)
          ].compact)
        end
      end
    end
  end

  def workspace_metric_card(label:, value:, description:, value_class: nil, icon: nil)
    content_tag(:div, class: "workspace-metric-card") do
      safe_join([
        (content_tag(:span, workspace_icon(icon), class: "workspace-metric-card__icon") if icon.present?),
        content_tag(:div, class: "workspace-metric-card__body") do
          safe_join([
            content_tag(:p, label, class: "workspace-metric-card__label"),
            content_tag(:p, value, class: workspace_class_names("workspace-metric-card__value", value_class)),
            content_tag(:p, description, class: "workspace-metric-card__description")
          ])
        end
      ].compact)
    end
  end

  def workspace_icon(name, classes: nil)
    paths = WORKSPACE_ICON_PATHS[name.to_sym]
    return "".html_safe if paths.blank?

    content_tag(:svg,
                class: workspace_class_names("workspace-icon", classes),
                viewBox: "0 0 24 24", fill: "none", aria: { hidden: true }, focusable: false) do
      safe_join(paths.map do |path|
        tag.path(d: path, stroke: "currentColor", 'stroke-width': 1.8, 'stroke-linecap': "round", 'stroke-linejoin': "round")
      end)
    end
  end

  def workspace_notifications
    return [] unless current_user

    @workspace_notifications ||= begin
      items = []
      imports = current_user.supplier_imports
      commercial = current_user.commercial_opportunities

      import_status_counts = imports.group(:status).count
      pending_imports = import_status_counts.fetch(SupplierImport::LOCAL_STATUS_PENDING, 0)
      processing_imports = import_status_counts.fetch(SupplierImport::LOCAL_STATUS_PROCESSING, 0)
      ready_exports = imports.where(result_ready: true).count
      import_errors = import_status_counts.fetch(SupplierImport::LOCAL_STATUS_ERROR, 0)
      pending_commercial = commercial.where(status: CommercialOpportunity::STATUS_PENDING).count

      if pending_imports.positive? && current_user.can_start_validation?
        items << {
          icon: :clock,
          tone: :warning,
          title: "Lotes aguardando início",
          body: "#{pending_imports} lote#{'s' if pending_imports != 1} pronto#{'s' if pending_imports != 1} para iniciar.",
          path: supplier_imports_path(status: SupplierImport::LOCAL_STATUS_PENDING)
        }
      end

      if processing_imports.positive?
        items << {
          icon: :validation,
          tone: :info,
          title: "Validação em andamento",
          body: "#{processing_imports} lote#{'s' if processing_imports != 1} sendo processado#{'s' if processing_imports != 1}.",
          path: supplier_imports_path(status: SupplierImport::LOCAL_STATUS_PROCESSING)
        }
      end

      if ready_exports.positive? && current_user.can_export_data?
        items << {
          icon: :database,
          tone: :success,
          title: "Resultados disponíveis",
          body: "#{ready_exports} resultado#{'s' if ready_exports != 1} pronto#{'s' if ready_exports != 1} para exportação.",
          path: supplier_imports_path(status: SupplierImport::LOCAL_STATUS_COMPLETED)
        }
      end

      if pending_commercial.positive? && current_user.can_start_validation?
        items << {
          icon: :commercial,
          tone: :commercial,
          title: "Retornos comerciais pendentes",
          body: "#{pending_commercial} fornecedor#{'es' if pending_commercial != 1} aguardando coleta comercial.",
          path: commercial_opportunities_path(status: CommercialOpportunity::STATUS_PENDING)
        }
      end

      if import_errors.positive?
        items << {
          icon: :bell,
          tone: :danger,
          title: "Lotes com erro",
          body: "#{import_errors} lote#{'s' if import_errors != 1} precisa#{'m' if import_errors != 1} de atenção.",
          path: supplier_imports_path(status: SupplierImport::LOCAL_STATUS_ERROR)
        }
      end

      items
    end
  end

  def workspace_metric_cell(label:, value:, value_class: nil)
    content_tag(:div, class: "workspace-metric-cell") do
      safe_join([
        content_tag(:p, label, class: "workspace-metric-cell__label"),
        content_tag(:p, value, class: workspace_class_names("workspace-metric-cell__value", value_class))
      ])
    end
  end

  def workspace_definition_row(label:, value: nil, &block)
    content_tag(:div, class: "workspace-definition-row") do
      safe_join([
        content_tag(:p, label, class: "workspace-definition-row__label"),
        content_tag(:div, block_given? ? capture(&block) : value, class: "workspace-definition-row__value")
      ])
    end
  end

  def settings_panel(classes: "p-6 sm:p-8 lg:p-10", &block)
    content_tag(:section, class: workspace_class_names("settings-panel", classes)) do
      capture(&block)
    end
  end

  def settings_feedback_messages
    notice = flash[:notice].presence || flash.now[:notice].presence
    alert = flash.now[:alert].presence || flash[:alert].presence

    safe_join([
      (settings_feedback_tag(notice, variant: :notice) if notice.present?),
      (settings_feedback_tag(alert, variant: :alert) if alert.present?)
    ].compact)
  end

  def settings_feedback_tag(message, variant:)
    content_tag(:div, message, class: "settings-feedback settings-feedback--#{variant}")
  end

  def platform_settings_page(title:, kicker: "Integração", description: nil, max_width: "max-w-5xl", tutorial_key: nil, &block)
    workspace_page(max_width:) do
      turbo_frame_tag "platform_settings_content" do
        safe_join([
          workspace_page_header(kicker:, title:, description:),
          render("platform_settings/nav"),
          capture(&block),
          (render("shared/workspace_tutorial", steps: workspace_tutorial_steps(tutorial_key)) if tutorial_key.present?)
        ].compact)
      end
    end
  end

  def workspace_class_names(*classes)
    classes.flatten.compact.flat_map { |klass| klass.to_s.split(/\s+/) }.reject(&:blank?).uniq.join(" ")
  end

  def workspace_status_tag(status)
    css_class = WORKSPACE_STATUS_VARIANTS[status.to_s]
    classes = [ "workspace-status" ]
    classes << css_class if css_class.present?
    classes.concat(%w[bg-slate-100 text-slate-600]) if css_class.blank?

    content_tag(:span, local_status_label(status), class: classes.join(" "))
  end

  def local_status_label(status)
    normalized_status = status.to_s.strip
    return I18n.t("shared.statuses.awaiting_submission") if normalized_status.blank?

    I18n.t("shared.statuses.#{normalized_status}", default: normalized_status.tr("_-", " ").capitalize)
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

  def audit_result_tag(result_code)
    normalized = result_code.to_s.strip
    css_class = AUDIT_RESULT_VARIANTS[normalized]
    classes = [ "workspace-status" ]
    classes << css_class if css_class.present?
    classes.concat(%w[bg-slate-100 text-slate-600]) if css_class.blank?

    label =
      if normalized.blank?
        I18n.t("validation_audits.index.results.unknown")
      else
        I18n.t(
          "validation_audits.index.results.#{normalized}",
          default: normalized.tr("_-", " ").capitalize
        )
      end

    content_tag(:span, label, class: classes.join(" "))
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

    started_at = Time.zone.parse(attempt["started_at"].to_s) if attempt["started_at"].present?
    finished_at = Time.zone.parse(attempt["finished_at"].to_s) if attempt["finished_at"].present?
    return "-" if started_at.blank? || finished_at.blank?

    "#{(finished_at - started_at).round(1)} s"
  rescue ArgumentError, TypeError
    "-"
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
