class AuditReview < ApplicationRecord
  RESULT_OPTIONS = %w[
    confirmed_by_call
    confirmed_by_whatsapp
    confirmed_by_email
    validated
    qualified_supplier
    wrong_company
    does_not_supply_segment
    not_interested
    privacy_refusal
    not_answered
    inconclusive
    inconclusive_call
    validation_failed
    invalid_phone
  ].freeze

  belongs_to :user
  belongs_to :supplier_import

  validates :reviewed_result, presence: true, inclusion: { in: RESULT_OPTIONS }
  validates :reviewed_at, presence: true
end
