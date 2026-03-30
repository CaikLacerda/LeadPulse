module ApplicationHelper
  WORKSPACE_TIME_ZONE = 'America/Sao_Paulo'.freeze

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
    validation_audits: [
      { key: :filters, selector: '[data-tutorial-id="audit-filters"]' },
      { key: :results, selector: '[data-tutorial-id="audit-results"]' },
      { key: :transcripts, selector: '[data-tutorial-id="audit-transcripts"]' }
    ]
  }.freeze

  WORKSPACE_STATUS_VARIANTS = {
    SupplierImport::LOCAL_STATUS_PENDING => 'workspace-status--warning',
    SupplierImport::LOCAL_STATUS_PROCESSING => 'workspace-status--info',
    SupplierImport::LOCAL_STATUS_COMPLETED => 'workspace-status--success',
    SupplierImport::LOCAL_STATUS_ERROR => 'workspace-status--danger'
  }.freeze

  AUDIT_RESULT_VARIANTS = {
    'confirmed_by_call' => 'workspace-status--success',
    'confirmed_by_whatsapp' => 'workspace-status--success',
    'confirmed_by_email' => 'workspace-status--success',
    'validated' => 'workspace-status--success',
    'success' => 'workspace-status--success',
    'inconclusive' => 'workspace-status--warning',
    'inconclusive_call' => 'workspace-status--warning',
    'answered' => 'workspace-status--info',
    'accepted' => 'workspace-status--info',
    'processing' => 'workspace-status--info',
    'validation_failed' => 'workspace-status--danger',
    'invalid_phone' => 'workspace-status--danger',
    'failed' => 'workspace-status--danger',
    'error' => 'workspace-status--danger'
  }.freeze

  def workspace_status_tag(status)
    css_class = WORKSPACE_STATUS_VARIANTS[status.to_s]
    classes = ['workspace-status']
    classes << css_class if css_class.present?
    classes.concat(%w[bg-slate-100 text-slate-600]) if css_class.blank?

    content_tag(:span, local_status_label(status), class: classes.join(' '))
  end

  def local_status_label(status)
    normalized_status = status.to_s.strip
    return I18n.t('shared.statuses.awaiting_submission') if normalized_status.blank?

    I18n.t("shared.statuses.#{normalized_status}", default: normalized_status.tr('_-', ' ').capitalize)
  end

  def translated_remote_batch_status(status)
    case status.to_s.strip.downcase
    when '', nil
      I18n.t('shared.remote_batch_statuses.awaiting_submission')
    when 'accepted'
      I18n.t('shared.remote_batch_statuses.accepted')
    when 'pending'
      I18n.t('shared.remote_batch_statuses.pending')
    when 'queued'
      I18n.t('shared.remote_batch_statuses.queued')
    when 'processing', 'in_progress', 'in-progress'
      I18n.t('shared.remote_batch_statuses.processing')
    when 'completed', 'complete'
      I18n.t('shared.remote_batch_statuses.completed')
    when 'failed', 'error'
      I18n.t('shared.remote_batch_statuses.failed')
    when 'cancelled', 'canceled'
      I18n.t('shared.remote_batch_statuses.cancelled')
    else
      status.to_s.tr('_-', ' ').strip.capitalize.presence || I18n.t('shared.remote_batch_statuses.awaiting_submission')
    end
  end

  def pagination_series(current_page, total_pages, window: 1)
    return [] if total_pages <= 1

    pages = [1, total_pages]
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
      default: workflow_kind.to_s.tr('_', ' ').capitalize
    )
  end

  def audit_result_tag(result_code)
    normalized = result_code.to_s.strip
    css_class = AUDIT_RESULT_VARIANTS[normalized]
    classes = ['workspace-status']
    classes << css_class if css_class.present?
    classes.concat(%w[bg-slate-100 text-slate-600]) if css_class.blank?

    label =
      if normalized.blank?
        I18n.t('validation_audits.index.results.unknown')
      else
        I18n.t(
          "validation_audits.index.results.#{normalized}",
          default: normalized.tr('_-', ' ').capitalize
        )
      end

    content_tag(:span, label, class: classes.join(' '))
  end

  def workspace_date(value)
    workspace_timestamp(value, format: '%d/%m/%Y')
  end

  def workspace_time(value)
    workspace_timestamp(value, format: '%H:%M')
  end

  def workspace_datetime(value)
    workspace_timestamp(value, format: '%d/%m/%Y %H:%M')
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

  def workspace_timestamp(value, format:)
    return '—' if value.blank?

    I18n.l(value.in_time_zone(WORKSPACE_TIME_ZONE), format: format)
  end
end
