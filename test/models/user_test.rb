require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "does not infer provider readiness from non-secret local metadata" do
    user = users(:one)
    user.validation_twilio_account_sid = "AC123"
    user.validation_twilio_phone_numbers = [ { "phone_number" => "+5511999999999" } ]

    assert_not user.validation_twilio_configured?
  end

  test "is validation ready only when the api confirms both providers" do
    user = users(:one)
    user.validation_account_id = 42
    user.validation_api_token_prefix = "tkn_live"
    user.validation_api_token = User.encrypt_validation_api_token("tkn_live_test")
    user.validation_account_response = {
      "twilio" => { "configured" => true },
      "openai" => { "configured" => true }
    }

    assert user.validation_twilio_configured?
    assert user.validation_openai_configured?
    assert user.validation_ready?
  end

  test "does not treat a corrupted encrypted api token as plaintext" do
    user = users(:one)
    user.validation_api_token = "#{User::TOKEN_ENCRYPTION_PREFIX}corrupted"

    assert_nil user.validation_api_token_value
    assert_not user.validation_api_token_configured?
  end

  test "validates provider settings before remote synchronization" do
    user = users(:one)
    user.validation_owner_email = "email-invalido"
    user.validation_twilio_webhook_base_url = "http://inseguro.example"
    user.validation_openai_realtime_output_speed = 2

    assert_not user.valid?
    assert user.errors[:validation_owner_email].present?
    assert user.errors[:validation_twilio_webhook_base_url].present?
    assert user.errors[:validation_openai_realtime_output_speed].present?
  end
end
