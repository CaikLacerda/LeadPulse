class CreateSupplierImports < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.binary :xlsx_data
      t.binary :valid_xlsx_data
      t.binary :invalid_xlsx_data
      t.string :status
      t.integer :total_rows, null: false, default: 0
      t.integer :valid_rows, null: false, default: 0
      t.integer :invalid_rows, null: false, default: 0

      t.timestamps
    end
  end
end
