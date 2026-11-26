class CreatePrivacyRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :privacy_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :supplier_import, foreign_key: true
      t.string :request_type, null: false
      t.string :status, null: false, default: 'open'
      t.string :subject_name
      t.string :subject_contact
      t.string :supplier_name
      t.string :phone
      t.text :description
      t.text :resolution
      t.datetime :requested_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :privacy_requests, [ :user_id, :status ]
  end
end
