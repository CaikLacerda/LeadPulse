class CreateAuditReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :supplier_import, null: false, foreign_key: true
      t.string :record_external_id
      t.string :provider_call_id
      t.integer :attempt_number
      t.string :original_result
      t.string :reviewed_result, null: false
      t.text :review_note
      t.datetime :reviewed_at, null: false

      t.timestamps
    end

    add_index :audit_reviews,
              [ :user_id, :supplier_import_id, :record_external_id, :provider_call_id, :attempt_number ],
              unique: true,
              name: "index_audit_reviews_on_lookup"
  end
end
