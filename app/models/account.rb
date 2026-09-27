# Empresa cliente do LeadPulse. É o tenant: lotes, buscas, retornos, auditoria,
# integrações e política LGPD pertencem à conta, e os usuários participam dela por AccountMembership.
class Account < ApplicationRecord
  has_many :account_memberships, dependent: :destroy
  has_many :users, through: :account_memberships

  has_many :supplier_imports, dependent: :destroy
  has_many :supplier_discovery_searches, dependent: :destroy
  has_many :commercial_opportunities, dependent: :destroy
  has_many :audit_reviews, dependent: :destroy
  has_many :privacy_requests, dependent: :destroy
  has_many :third_party_operators, dependent: :destroy
  has_many :privacy_audit_events, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
end
