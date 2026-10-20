# Fase 2 do tenancy final: o vínculo usuário/empresa ganha estado e autoria do convite.
# Convites pendentes ficam em account_invitations; aqui só existem vínculos ativos ou
# desativados (remover alguém da empresa desativa o vínculo, sem apagar o usuário).
class AddStatusToAccountMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :account_memberships, :status, :string, null: false, default: "active"
    add_column :account_memberships, :disabled_at, :datetime
    add_reference :account_memberships, :invited_by, foreign_key: { to_table: :users, on_delete: :nullify }
    add_index :account_memberships, [ :account_id, :status ]
    add_check_constraint :account_memberships, "role IN ('admin', 'manager', 'operator', 'auditor', 'viewer')", name: "account_memberships_role_check"
    add_check_constraint :account_memberships, "status IN ('active', 'disabled')", name: "account_memberships_status_check"
  end
end
