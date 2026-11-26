class DropProviderSecretColumnsFromUsers < ActiveRecord::Migration[8.1]
  def up
    remove_column :users, :validation_twilio_auth_token, :text if column_exists?(:users, :validation_twilio_auth_token)
    remove_column :users, :validation_openai_api_key, :text if column_exists?(:users, :validation_openai_api_key)
  end

  def down
    add_column :users, :validation_twilio_auth_token, :text unless column_exists?(:users, :validation_twilio_auth_token)
    add_column :users, :validation_openai_api_key, :text unless column_exists?(:users, :validation_openai_api_key)
  end
end
