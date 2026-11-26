class RemoveLocallyStoredProviderSecrets < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE users
      SET validation_twilio_auth_token = NULL,
          validation_openai_api_key = NULL
    SQL
  end

  def down
    # Provider secrets remain encrypted in the API and cannot be reconstructed here.
  end
end
