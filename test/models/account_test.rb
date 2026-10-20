require "test_helper"

class AccountTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "does not infer provider readiness from non-secret local metadata" do
    @account.validation_twilio_account_sid = "AC123"
    @account.validation_twilio_phone_numbers = [ { "phone_number" => "+5511999999999" } ]

    assert_not @account.validation_twilio_configured?
  end

  test "is validation ready only when the api confirms both providers" do
    @account.validation_account_id = 42
    @account.validation_api_token_prefix = "tkn_live"
    @account.validation_api_token = Account.encrypt_validation_api_token("tkn_live_test")
    @account.validation_account_response = {
      "twilio" => { "configured" => true },
      "openai" => { "configured" => true }
    }

    assert @account.validation_twilio_configured?
    assert @account.validation_openai_configured?
    assert @account.validation_ready?
  end

  test "does not treat a corrupted encrypted api token as plaintext" do
    @account.validation_api_token = "#{Account::TOKEN_ENCRYPTION_PREFIX}corrupted"

    assert_nil @account.validation_api_token_value
    assert_not @account.validation_api_token_configured?
  end

  test "reads a token encrypted with the key previously used for users" do
    legacy_key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
      .generate_key("leadpulse-validation-api-token", ActiveSupport::MessageEncryptor.key_len)
    legacy_ciphertext = "enc:v1:" + ActiveSupport::MessageEncryptor.new(legacy_key).encrypt_and_sign("tkn_live_migrated")

    @account.validation_api_token = legacy_ciphertext

    assert_equal "tkn_live_migrated", @account.validation_api_token_value
  end

  test "validates provider settings before remote synchronization" do
    @account.validation_owner_email = "email-invalido"
    @account.validation_twilio_webhook_base_url = "http://inseguro.example"
    @account.validation_openai_realtime_output_speed = 2

    assert_not @account.valid?
    assert @account.errors[:validation_owner_email].present?
    assert @account.errors[:validation_twilio_webhook_base_url].present?
    assert @account.errors[:validation_openai_realtime_output_speed].present?
  end

  test "limits the institutional calling profile to the API limit" do
    @account.validation_calling_profile = "a" * 1_501

    assert_not @account.valid?
    assert @account.errors[:validation_calling_profile].present?
  end

  test "accepts GPT Live as a voice model option" do
    @account.validation_openai_realtime_model = "gpt-live-1"

    assert @account.valid?
  end

  test "uses the first administrator as the default owner" do
    assert_equal users(:one).name, @account.validation_owner_name_value
    assert_equal users(:one).email, @account.validation_owner_email_value
  end

  test "keeps the external reference already known by the validation API" do
    @account.validation_external_account_id = "leadpulse_user_7"

    assert_equal "leadpulse_user_7", @account.validation_external_account_reference
  end

  test "new accounts get an account-based external reference" do
    assert_equal "leadpulse_account_#{@account.id}", @account.validation_external_account_reference
  end
end
