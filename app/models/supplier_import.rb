class SupplierImport < ApplicationRecord
  include HasDisplayCode

  LOCAL_STATUS_PENDING = 'pendente'.freeze
  LOCAL_STATUS_PROCESSING = 'processando'.freeze
  LOCAL_STATUS_COMPLETED = 'concluido'.freeze
  LOCAL_STATUS_ERROR = 'erro'.freeze
  WORKFLOW_KIND_CADASTRAL = 'cadastral_validation'.freeze
  WORKFLOW_KIND_SUPPLIER = 'supplier_validation'.freeze
  SOURCE_UPLOAD = 'integracao_externa'.freeze
  SOURCE_SUPPLIER_DISCOVERY = 'supplier_discovery'.freeze

  WORKFLOW_KIND_LABELS = {
    WORKFLOW_KIND_CADASTRAL => 'Cadastral',
    WORKFLOW_KIND_SUPPLIER => 'Segmento'
  }.freeze

  SOURCE_LABELS = {
    SOURCE_UPLOAD => 'Upload',
    SOURCE_SUPPLIER_DISCOVERY => 'Busca web'
  }.freeze

  belongs_to :user
  has_many :suppliers
  has_many :supplier_import_versions

  scope :active_remote, -> { where(status: LOCAL_STATUS_PROCESSING).where.not(remote_batch_id: [nil, '']) }
  display_code_prefix 'LD'

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
end
