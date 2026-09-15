class PrivacyRequest < ApplicationRecord
  REQUEST_TYPES = {
    access: "Acesso aos dados",
    correction: "Correção de dados",
    deletion: "Exclusão",
    anonymization: "Anonimização",
    sharing_info: "Informação sobre compartilhamento",
    consent_revocation: "Revogação/autorização"
  }.freeze

  STATUSES = {
    open: "Aberta",
    in_progress: "Em análise",
    resolved: "Resolvida",
    rejected: "Recusada"
  }.freeze

  belongs_to :user
  belongs_to :supplier_import, optional: true

  validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES.keys.map(&:to_s) }
  validates :status, presence: true, inclusion: { in: STATUSES.keys.map(&:to_s) }
  validates :requested_at, presence: true
  validates :subject_name, :subject_contact, presence: true
  validates :subject_name, :supplier_name, length: { maximum: 255 }, allow_blank: true
  validates :subject_contact, length: { maximum: 320 }
  validates :phone, length: { maximum: 32 }, allow_blank: true
  validates :description, :resolution, length: { maximum: 4_000 }, allow_blank: true
  validate :supplier_import_belongs_to_user

  before_validation :set_defaults

  def request_type_label
    REQUEST_TYPES.fetch(request_type.to_sym, request_type.to_s.humanize)
  end

  def status_label
    STATUSES.fetch(status.to_sym, status.to_s.humanize)
  end

  private

  def set_defaults
    self.requested_at ||= Time.current
    self.status = "open" if status.blank?
  end

  def supplier_import_belongs_to_user
    return if supplier_import.blank? || user.blank?
    return if supplier_import.user_id == user_id

    errors.add(:supplier_import, "deve pertencer à mesma conta da solicitação")
  end
end
