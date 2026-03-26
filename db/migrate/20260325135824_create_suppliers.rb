class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.references :supplier_import, foreign_key: true

      t.string :name, null: false
      t.string :company_name, null: false
      t.string :document
      t.string :phone_status
      t.string :normalized_phone
      t.string :phone_source
      t.string :phone_raw

      t.timestamps
    end

    add_index :suppliers, :document
    add_index :suppliers, :normalized_phone
    end
end
