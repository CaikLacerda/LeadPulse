class PrivacyAuditEvent < ApplicationRecord
  belongs_to :user
  belongs_to :supplier_import, optional: true

  validates :action, :occurred_at, presence: true

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
