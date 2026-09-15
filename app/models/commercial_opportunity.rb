class CommercialOpportunity < ApplicationRecord
  include HasDisplayCode

  STATUS_PENDING = "pendente".freeze
  STATUS_PROCESSING = "processando".freeze
  STATUS_COMPLETED = "concluido".freeze
  STATUS_ERROR = "erro".freeze
  STATUSES = [ STATUS_PENDING, STATUS_PROCESSING, STATUS_COMPLETED, STATUS_ERROR ].freeze

  belongs_to :user
  belongs_to :supplier_import

  validates :source_external_id, :supplier_name, :callback_phone, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source_external_id, uniqueness: { scope: :supplier_import_id }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :active_remote, -> { where(status: STATUS_PROCESSING).where.not(remote_batch_id: [ nil, "" ]) }

  display_code_prefix "RC"

  def pending?
    status == STATUS_PENDING
  end

  def processing?
    status == STATUS_PROCESSING
  end

  def completed?
    status == STATUS_COMPLETED
  end

  def errored?
    status == STATUS_ERROR
  end

  def startable?
    pending? || errored?
  end

  def syncable?
    remote_batch_id.present? && started_at.present?
  end

  def ready_to_export?
    result_ready? || completed?
  end

  def source_import_code
    supplier_import.display_code
  end

  def export_xlsx_filename
    "retorno-comercial-#{display_number}.xlsx"
  end

  def callback_phone_choice_label
    return "Mesmo número atendido" if callback_phone_choice == "same_number"
    return "Número alternativo informado" if callback_phone_choice == "alternate_number"

    "Número confirmado na validação"
  end

  def callback_schedule_label
    return callback_preferred_time.presence || "Sem preferência" if callback_preferred_at.blank?

    I18n.l(
      callback_preferred_at.in_time_zone("America/Sao_Paulo"),
      format: "%d/%m/%Y às %H:%M"
    )
  end

  def outcome_label
    {
      "collected" => "Informações coletadas",
      "refused" => "Informações recusadas",
      "not_answered" => "Não atendida",
      "inconclusive" => "Inconclusiva",
      "privacy_refusal" => "Interrompida por solicitação"
    }.fetch(outcome.to_s, outcome.to_s.humanize.presence || "Aguardando resultado")
  end

  def display_product_specification
    normalized_value(:normalized_product_specification) || product_specification
  end

  def display_unit_price
    normalized_value(:normalized_unit_price) || unit_price
  end

  def display_lot_price_ranges
    normalized_value(:normalized_lot_price_ranges) || lot_price_ranges
  end

  def display_minimum_order
    normalized_value(:normalized_minimum_order) || minimum_order
  end

  def original_commercial_terms_differ?
    commercial_term_pairs.any? do |normalized, original|
      normalized.present? && original.present? && normalized.strip != original.strip
    end
  end

  private

  def normalized_value(attribute)
    return unless has_attribute?(attribute)

    self[attribute].presence
  end

  def commercial_term_pairs
    [
      [ normalized_value(:normalized_product_specification), product_specification ],
      [ normalized_value(:normalized_unit_price), unit_price ],
      [ normalized_value(:normalized_lot_price_ranges), lot_price_ranges ],
      [ normalized_value(:normalized_minimum_order), minimum_order ]
    ]
  end
end
