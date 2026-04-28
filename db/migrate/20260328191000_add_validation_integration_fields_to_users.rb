class AddValidationIntegrationFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :validation_account_id, :bigint
    add_column :users, :validation_external_account_id, :string
    add_column :users, :validation_company_name, :string
    add_column :users, :validation_spoken_company_name, :string
    add_column :users, :validation_owner_name, :string
    add_column :users, :validation_owner_email, :string

    add_column :users, :validation_twilio_account_sid, :string
    add_column :users, :validation_twilio_auth_token, :text
    add_column :users, :validation_twilio_webhook_base_url, :string
    add_column :users, :validation_twilio_phone_numbers, :jsonb, default: [], null: false

    add_column :users, :validation_openai_api_key, :text
    add_column :users, :validation_openai_realtime_model, :string, default: 'gpt-realtime-1.5', null: false
    add_column :users, :validation_openai_realtime_voice, :string, default: 'cedar', null: false
    add_column :users, :validation_openai_realtime_output_speed, :decimal, precision: 4, scale: 2
    add_column :users, :validation_openai_style_instructions, :text

    add_column :users, :validation_api_token, :text
    add_column :users, :validation_api_token_prefix, :string
    add_column :users, :validation_api_token_created_at, :datetime
    add_column :users, :validation_account_response, :jsonb, default: {}, null: false
  end
end
