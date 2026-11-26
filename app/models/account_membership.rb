# Vínculo de um usuário com uma empresa (Account). O papel pertence ao vínculo:
# a mesma pessoa pode ser admin numa empresa e visualizadora em outra.
#
# Todas as regras de permissão do produto ficam aqui, num único lugar. Remover alguém da
# empresa desativa o vínculo; o usuário continua existindo.
class AccountMembership < ApplicationRecord
  ROLES = {
    "admin" => "Administrador",
    "manager" => "Gestor",
    "operator" => "Operador",
    "auditor" => "Auditor",
    "viewer" => "Visualizador"
  }.freeze

  STATUS_ACTIVE = "active".freeze
  STATUS_DISABLED = "disabled".freeze
  STATUSES = {
    STATUS_ACTIVE => "Ativo",
    STATUS_DISABLED => "Desativado"
  }.freeze

  belongs_to :account
  belongs_to :user
  belongs_to :invited_by, class_name: "User", optional: true

  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :admins, -> { active.where(role: "admin") }

  validates :role, inclusion: { in: ROLES.keys }
  validates :status, inclusion: { in: STATUSES.keys }
  validates :user_id, uniqueness: { scope: :account_id }
  validate :account_keeps_an_active_admin, on: :update

  before_destroy :ensure_not_last_admin

  def role_label
    ROLES.fetch(role.to_s, role.to_s.humanize)
  end

  def status_label
    STATUSES.fetch(status.to_s, status.to_s.humanize)
  end

  def active?
    status == STATUS_ACTIVE
  end

  def disabled?
    status == STATUS_DISABLED
  end

  def admin?
    role == "admin"
  end

  def last_active_admin?
    active? && admin? && !account.account_memberships.admins.where.not(id: id).exists?
  end

  def disable!
    update!(status: STATUS_DISABLED, disabled_at: Time.current)
  end

  def reactivate!(role: self.role, invited_by: self.invited_by)
    update!(status: STATUS_ACTIVE, disabled_at: nil, role: role, invited_by: invited_by)
  end

  # Permissões

  def can_manage_lgpd?
    admin?
  end

  def can_manage_settings?
    admin?
  end

  def can_manage_team?
    admin?
  end

  def can_manage_bi_tokens?
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

  private

  # Uma empresa nunca fica sem administrador ativo: quem é o último não pode perder o papel
  # nem ser desativado.
  def account_keeps_an_active_admin
    was_active_admin = status_was == STATUS_ACTIVE && role_was == "admin"
    still_active_admin = active? && admin?
    return unless was_active_admin && !still_active_admin
    return if account.account_memberships.admins.where.not(id: id).exists?

    errors.add(:base, "A empresa precisa de pelo menos um administrador ativo.")
  end

  def ensure_not_last_admin
    return if destroyed_by_association
    return unless last_active_admin?

    errors.add(:base, "A empresa precisa de pelo menos um administrador ativo.")
    throw :abort
  end
end
