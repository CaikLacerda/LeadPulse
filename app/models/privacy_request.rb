class PrivacyRequest < ApplicationRecord
  REQUEST_TYPES = {
    access: 'Acesso aos dados',
    correction: 'Correção de dados',
    deletion: 'Exclusão',
    anonymization: 'Anonimização',
    sharing_info: 'Informação sobre compartilhamento',
    consent_revocation: 'Revogação/autorização'
  }.freeze

  STATUSES = {
    open: 'Aberta',
    in_progress: 'Em análise',
    resolved: 'Resolvida',
    rejected: 'Recusada'
  }.freeze

  belongs_to :user
  belongs_to :supplier_import, optional: true

  validates :request_type, presence: true, inclusion: { in: REQUEST_TYPES.keys.map(&:to_s) }
  validates :status, presence: true, inclusion: { in: STATUSES.keys.map(&:to_s) }
  validates :requested_at, presence: true
  validates :subject_name, :subject_contact, presence: true

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
    self.status = 'open' if status.blank?
  end
end
