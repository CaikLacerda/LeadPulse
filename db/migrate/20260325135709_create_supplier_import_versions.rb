class CreateSupplierImportVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_import_versions do |t|
      t.references :supplier_import, null: false, foreign_key: true
      t.integer :size
      t.string :event
      t.string :event_type

      t.timestamps
    end
  end
end
