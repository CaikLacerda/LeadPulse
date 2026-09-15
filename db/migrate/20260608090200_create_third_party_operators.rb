class CreateThirdPartyOperators < ActiveRecord::Migration[8.1]
  def change
    create_table :third_party_operators do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :service_type, null: false
      t.text :data_shared
      t.text :purpose
      t.string :country
      t.string :contract_reference
      t.string :technical_owner
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :third_party_operators, [ :user_id, :active ]
  end
end
