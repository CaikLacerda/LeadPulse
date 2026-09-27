# Pessoa que acessa o LeadPulse. Os dados de negócio pertencem à empresa (Account);
# o usuário participa de uma ou mais empresas por AccountMembership, onde fica o seu papel.
#
# Nas tabelas de negócio, user_id indica quem fez a ação (importou, revisou, registrou), não o tenant.
# As colunas de empresa, integração e role que ainda existem em users foram copiadas para
# accounts/account_memberships e não são mais lidas pela aplicação.
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :account_memberships, dependent: :destroy
  has_many :accounts, through: :account_memberships
  has_many :workspace_notification_reads, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
end
