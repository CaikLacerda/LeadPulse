class PrivacyAuditEvent < ApplicationRecord
  include MatchesSupplierImportAccount

  belongs_to :account
  # Quem fez a ação; o isolamento entre empresas é por account.
  # Quem fez a ação. Vazio em ações automáticas do sistema (ex.: retenção).
  belongs_to :performed_by, class_name: "User", optional: true
  belongs_to :supplier_import, optional: true

  validates :action, :occurred_at, presence: true
  validates :action, :resource_id, length: { maximum: 120 }, allow_blank: true
  validates :resource_type, length: { maximum: 255 }, allow_blank: true

  before_validation :set_defaults

  def action_label
    I18n.t("privacy_audit_events.actions.#{action}", default: action.to_s.humanize)
  end

  private

  def set_defaults
    self.occurred_at ||= Time.current
    self.metadata ||= {}
  end
end
