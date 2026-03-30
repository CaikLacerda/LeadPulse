class CreateSupplierDiscoverySearches < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_discovery_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :search_id, null: false
      t.string :status, null: false, default: 'concluido'
      t.string :mode
      t.string :segment_name, null: false
      t.string :region
      t.string :callback_phone
      t.string :callback_contact_name
      t.integer :total_suppliers, null: false, default: 0
      t.datetime :generated_at
      t.jsonb :request_payload, null: false, default: {}
      t.jsonb :response_payload, null: false, default: {}
      t.binary :results_xlsx_data
      t.string :results_filename
      t.text :error_message

      t.timestamps
    end

    add_index :supplier_discovery_searches, [:user_id, :search_id], unique: true
  end
end
