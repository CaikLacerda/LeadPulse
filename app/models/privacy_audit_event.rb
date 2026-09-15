class PrivacyAuditEvent < ApplicationRecord
  belongs_to :user
  belongs_to :supplier_import, optional: true

  validates :action, :occurred_at, presence: true
  validates :action, :resource_id, length: { maximum: 120 }, allow_blank: true
  validates :resource_type, length: { maximum: 255 }, allow_blank: true
  validate :supplier_import_belongs_to_user

  before_validation :set_defaults

  def action_label
    I18n.t("privacy_audit_events.actions.#{action}", default: action.to_s.humanize)
  end

  private

  def set_defaults
    self.occurred_at ||= Time.current
    self.metadata ||= {}
  end

  def supplier_import_belongs_to_user
    return if supplier_import.blank? || user.blank?
    return if supplier_import.user_id == user_id

    errors.add(:supplier_import, "deve pertencer à mesma conta do evento")
  end
end
