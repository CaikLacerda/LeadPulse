# Pessoa que acessa o LeadPulse. Os dados de negócio pertencem à empresa (Account);
# o usuário participa de uma ou mais empresas por AccountMembership, onde fica o seu papel.
#
# User guarda só identificação e autenticação. Credenciais, integrações e política LGPD são
# da empresa (Account); o papel é do vínculo (AccountMembership).
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :account_memberships, dependent: :destroy
  has_many :accounts, through: :account_memberships
  has_many :workspace_notification_reads, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
end
