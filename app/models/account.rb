# Empresa cliente do LeadPulse. É o tenant: lotes, buscas, retornos, auditoria,
# integrações e política LGPD pertencem à conta, e os usuários participam dela por AccountMembership.
class Account < ApplicationRecord
  has_many :account_memberships, dependent: :destroy
  has_many :users, through: :account_memberships

  validates :name, presence: true, length: { maximum: 255 }
end
