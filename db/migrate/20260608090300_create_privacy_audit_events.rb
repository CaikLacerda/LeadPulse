class CreatePrivacyAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :privacy_audit_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :supplier_import, foreign_key: true
      t.string :action, null: false
      t.string :resource_type
      t.string :resource_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :privacy_audit_events, [:user_id, :occurred_at]
    add_index :privacy_audit_events, [:user_id, :action]
  end
end
