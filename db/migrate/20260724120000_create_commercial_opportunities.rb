class CreateCommercialOpportunities < ActiveRecord::Migration[8.1]
  def change
    create_table :commercial_opportunities do |t|
      t.references :user, null: false, foreign_key: true
      t.references :supplier_import, null: false, foreign_key: true
      t.string :source_external_id, null: false
      t.string :supplier_name, null: false
      t.string :source_phone
      t.string :callback_phone, null: false
      t.string :callback_phone_choice
      t.text :callback_preferred_time
      t.string :segment_name
      t.string :status, null: false, default: 'pendente'
      t.string :remote_batch_id
      t.string :remote_batch_status
      t.jsonb :request_payload, null: false, default: {}
      t.jsonb :response_payload, null: false, default: {}
      t.boolean :result_ready, null: false, default: false
      t.text :product_specification
      t.text :unit_price
      t.text :lot_price_ranges
      t.text :minimum_order
      t.string :outcome
      t.datetime :started_at
      t.datetime :last_synced_at
      t.datetime :finished_at
      t.text :error_message

      t.timestamps
    end

    add_index :commercial_opportunities,
      [ :supplier_import_id, :source_external_id ],
      unique: true,
      name: 'index_commercial_opportunities_on_source_record'
    add_index :commercial_opportunities, :remote_batch_id
    add_index :commercial_opportunities, [ :user_id, :status ]
  end
end
