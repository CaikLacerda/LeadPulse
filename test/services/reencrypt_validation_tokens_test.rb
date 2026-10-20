require "test_helper"

class ReencryptValidationTokensTest < ActiveSupport::TestCase
  test "dry run preserves ciphertext and apply is reversible and idempotent" do
    old_secret = SecureRandom.hex(64)
    new_secret = SecureRandom.hex(64)
    old_encryptor = Account.validation_api_token_encryptor(secret: old_secret)
    token = "test-integration-token"
    account = Account.create!(name: "Rotation fixture", validation_api_token: Account::TOKEN_ENCRYPTION_PREFIX + old_encryptor.encrypt_and_sign(token))
    original = account.validation_api_token
    Account.where.not(id: account.id).update_all(validation_api_token: nil)

    assert_equal({ candidates: 1, changed: 0 }, Maintenance::ReencryptValidationTokens.new(old_secret: old_secret, new_secret: new_secret).call)
    assert_equal original, account.reload.validation_api_token
    service = Maintenance::ReencryptValidationTokens.new(old_secret: old_secret, new_secret: new_secret, apply: true)
    assert_equal({ candidates: 1, changed: 1 }, service.call)
    value = account.reload.validation_api_token.delete_prefix(Account::TOKEN_ENCRYPTION_PREFIX)
    assert_equal token, Account.validation_api_token_encryptor(secret: new_secret).decrypt_and_verify(value)
    assert_equal({ candidates: 0, changed: 0 }, service.call)
    Maintenance::ReencryptValidationTokens.new(old_secret: new_secret, new_secret: old_secret, apply: true).call
    assert_equal token, old_encryptor.decrypt_and_verify(account.reload.validation_api_token.delete_prefix(Account::TOKEN_ENCRYPTION_PREFIX))
  end

  test "an unreadable row rolls the entire transaction back without exposing its value" do
    old_secret = SecureRandom.hex(64)
    good = Account.create!(name: "Readable", validation_api_token: Account::TOKEN_ENCRYPTION_PREFIX + Account.validation_api_token_encryptor(secret: old_secret).encrypt_and_sign("fake"))
    bad = Account.create!(name: "Unreadable", validation_api_token: "enc:v1:invalid-secret-fixture")
    Account.where.not(id: [ good.id, bad.id ]).update_all(validation_api_token: nil)
    original = good.validation_api_token
    error = assert_raises(RuntimeError) do
      Maintenance::ReencryptValidationTokens.new(old_secret: old_secret, new_secret: SecureRandom.hex(64), apply: true).call
    end
    assert_equal original, good.reload.validation_api_token
    assert_no_match(/invalid-secret-fixture/, error.message)
  end
end
