class AddValidationCallingProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :validation_calling_profile, :text
  end
end
