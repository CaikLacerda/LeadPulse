class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :type, null: false
      t.integer :usage, null: false, default: 0
      t.numeric :value, null: false, default: 0
      t.integer :supplier_limit, null: false, default: 10

      t.timestamps
    end
  end
end
