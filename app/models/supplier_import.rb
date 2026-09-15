class SupplierImport < ApplicationRecord
  include HasDisplayCode

  LOCAL_STATUS_PENDING = "pendente".freeze
  LOCAL_STATUS_PROCESSING = "processando".freeze
  LOCAL_STATUS_COMPLETED = "concluido".freeze
  LOCAL_STATUS_ERROR = "erro".freeze
  WORKFLOW_KIND_CADASTRAL = "cadastral_validation".freeze
  WORKFLOW_KIND_SUPPLIER = "supplier_validation".freeze
  SOURCE_UPLOAD = "integracao_externa".freeze
  SOURCE_SUPPLIER_DISCOVERY = "supplier_discovery".freeze

  WORKFLOW_KIND_LABELS = {
    WORKFLOW_KIND_CADASTRAL => "Cadastral",
    WORKFLOW_KIND_SUPPLIER => "Segmento"
  }.freeze

  SOURCE_LABELS = {
    SOURCE_UPLOAD => "Upload",
    SOURCE_SUPPLIER_DISCOVERY => "Busca web"
  }.freeze

  belongs_to :user
  has_many :suppliers, dependent: :destroy
  has_many :supplier_import_versions, dependent: :destroy
  has_many :audit_reviews, dependent: :destroy
  has_many :commercial_opportunities, dependent: :destroy

  validates :status,
    presence: true,
    inclusion: { in: [ LOCAL_STATUS_PENDING, LOCAL_STATUS_PROCESSING, LOCAL_STATUS_COMPLETED, LOCAL_STATUS_ERROR ] }
  validates :workflow_kind,
    presence: true,
    inclusion: { in: [ WORKFLOW_KIND_CADASTRAL, WORKFLOW_KIND_SUPPLIER ] }
  validates :source,
    presence: true,
    inclusion: { in: [ SOURCE_UPLOAD, SOURCE_SUPPLIER_DISCOVERY ] }
  validates :total_rows, :valid_rows, :invalid_rows,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :row_totals_are_consistent

  scope :active_remote, -> { where(status: LOCAL_STATUS_PROCESSING).where.not(remote_batch_id: [ nil, "" ]) }
  display_code_prefix "LD"

  def pending?
    status == LOCAL_STATUS_PENDING
  end

  def processing?
    status == LOCAL_STATUS_PROCESSING
  end

  def completed?
    status == LOCAL_STATUS_COMPLETED
  end

  def errored?
    status == LOCAL_STATUS_ERROR
  end

  def supplier_validation?
    workflow_kind == WORKFLOW_KIND_SUPPLIER
  end

  def cadastral_validation?
    workflow_kind == WORKFLOW_KIND_CADASTRAL
  end

  def ready_to_export?
    result_ready? || completed?
  end

  def startable?
    pending? || errored?
  end

  def destroyable?
    pending? || errored? || ready_to_export?
  end

  def syncable?
    remote_batch_id.present? && validation_started_at.present?
  end

  def workflow_kind_label
    WORKFLOW_KIND_LABELS.fetch(workflow_kind, workflow_kind.to_s.humanize)
  end

  def source_label
    SOURCE_LABELS.fetch(source, source.to_s.humanize)
  end

  def export_filename
    "lote-#{display_number}-resultado.csv"
  end

  def export_xlsx_filename
    "lote-#{display_number}-resultado.xlsx"
  end

  def segment_name
    @segment_name.presence || import_metadata["segment_name"].presence || request_payload["segment_name"].presence
  end

  def segment_name=(value)
    @segment_name = value
    self.import_metadata = (import_metadata || {}).merge("segment_name" => value) if value.present?
  end

  def callback_phone
    @callback_phone.presence || import_metadata["callback_phone"].presence || request_payload["callback_phone"].presence
  end

  def callback_phone=(value)
    @callback_phone = value
    self.import_metadata = (import_metadata || {}).merge("callback_phone" => value) if value.present?
  end

  def callback_contact_name
    @callback_contact_name.presence || import_metadata["callback_contact_name"].presence || request_payload["callback_contact_name"].presence
  end

  def callback_contact_name=(value)
    @callback_contact_name = value
    self.import_metadata = (import_metadata || {}).merge("callback_contact_name" => value) if value.present?
  end

  def privacy_notice
    response_notice = response_payload["privacy_notice"] if response_payload.is_a?(Hash)
    metadata_notice = import_metadata["privacy_notice"] if import_metadata.is_a?(Hash)
    request_notice = request_payload["privacy_notice"] if request_payload.is_a?(Hash)

    notice = response_notice.presence || metadata_notice.presence || request_notice.presence || {}
    notice.respond_to?(:deep_stringify_keys) ? notice.deep_stringify_keys : {}
  end

  def evidence_expires_at
    value = privacy_notice["evidence_expires_at"]
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def evidence_anonymized?
    import_metadata["evidence_anonymized_at"].present? ||
      privacy_notice["evidence_anonymized_at"].present? ||
      Array(response_payload["records"]).any? { |record| record["evidence_anonymized"].present? }
  end

  def evidence_retention_expired?(now = Time.current)
    evidence_expires_at.present? && evidence_expires_at <= now && !evidence_anonymized?
  end

  private

  def row_totals_are_consistent
    return unless total_rows && valid_rows && invalid_rows
    return if valid_rows + invalid_rows <= total_rows

    errors.add(:base, "A soma de linhas válidas e inválidas não pode exceder o total de linhas.")
  end
end
