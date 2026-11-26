# Tokens somente leitura da API de Analytics (BI). Pertencem à empresa, não a quem os criou;
# created_by_id/revoked_by_id são autoria. Só o HMAC do token é gravado.
class CreateAnalyticsApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_api_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :revoked_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :analytics_api_tokens, :token_digest, unique: true
    add_index :analytics_api_tokens, [ :account_id, :revoked_at ]
  end
end
