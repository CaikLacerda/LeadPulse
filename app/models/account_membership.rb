# Vínculo de um usuário com uma empresa (Account). O papel pertence ao vínculo:
# a mesma pessoa pode ser admin numa empresa e visualizadora em outra.
#
# Todas as regras de permissão do produto ficam aqui, num único lugar.
class AccountMembership < ApplicationRecord
  ROLES = {
    "admin" => "Administrador",
    "manager" => "Gestor",
    "operator" => "Operador",
    "auditor" => "Auditor",
    "viewer" => "Visualizador"
  }.freeze

  belongs_to :account
  belongs_to :user

  validates :role, inclusion: { in: ROLES.keys }
  validates :user_id, uniqueness: { scope: :account_id }

  def role_label
    ROLES.fetch(role.to_s, role.to_s.humanize)
  end

  def admin?
    role == "admin"
  end

  def can_manage_lgpd?
    admin?
  end

  def can_manage_settings?
    admin?
  end

  def can_import_data?
    %w[admin manager].include?(role)
  end

  def can_start_validation?
    %w[admin manager operator].include?(role)
  end

  def can_export_data?
    %w[admin manager auditor].include?(role)
  end

  def can_view_evidence?
    %w[admin manager operator auditor].include?(role)
  end

  def can_anonymize_evidence?
    admin?
  end
end
