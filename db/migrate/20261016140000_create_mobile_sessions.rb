class CreateMobileSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :mobile_sessions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false
      t.string :password_fingerprint, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :mobile_sessions, :token_digest, unique: true
  end
end
