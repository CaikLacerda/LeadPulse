class AddRemoteValidationFieldsToSupplierImports < ActiveRecord::Migration[8.1]
  def change
    add_column :supplier_imports, :file_name, :string
    add_column :supplier_imports, :workflow_kind, :string, default: 'cadastral_validation', null: false
    add_column :supplier_imports, :source, :string, default: 'integracao_externa', null: false
    add_column :supplier_imports, :remote_batch_id, :string
    add_column :supplier_imports, :remote_batch_status, :string
    add_column :supplier_imports, :request_payload, :jsonb, default: {}, null: false
    add_column :supplier_imports, :response_payload, :jsonb, default: {}, null: false
    add_column :supplier_imports, :import_metadata, :jsonb, default: {}, null: false
    add_column :supplier_imports, :result_ready, :boolean, default: false, null: false
    add_column :supplier_imports, :validation_started_at, :datetime
    add_column :supplier_imports, :last_synced_at, :datetime
    add_column :supplier_imports, :finished_at, :datetime
    add_column :supplier_imports, :error_message, :text

    add_index :supplier_imports, :remote_batch_id
  end
end
