# Convites para entrar numa empresa. O token nunca é gravado: só o HMAC dele (token_digest).
# Cada e-mail tem no máximo um convite em aberto por empresa.
class CreateAccountInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :account_invitations do |t|
      t.references :account, null: false, foreign_key: true
      t.string :email, null: false
      t.string :role, null: false
      t.string :token_digest, null: false
      t.references :invited_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :accepted_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :sent_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :canceled_at
      t.timestamps
    end

    add_index :account_invitations, :token_digest, unique: true
    add_index :account_invitations, "account_id, lower(email)", unique: true,
      where: "accepted_at IS NULL AND canceled_at IS NULL", name: "index_account_invitations_open_email"
    add_check_constraint :account_invitations, "role IN ('admin', 'manager', 'operator', 'auditor', 'viewer')", name: "account_invitations_role_check"
  end
end
