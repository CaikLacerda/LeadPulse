require "test_helper"

class AnalyticsApiTokenTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "keeps only the HMAC and a visible prefix of the secret" do
    token = build_token
    secret = token.generate_secret
    token.save!

    assert secret.start_with?("lpbi_")
    assert_equal 45, secret.length
    assert_equal secret.first(12), token.token_prefix
    assert_not_includes AnalyticsApiToken.connection.select_value("SELECT row_to_json(t)::text FROM analytics_api_tokens t WHERE id = #{token.id}"), secret
    assert_equal token, AnalyticsApiToken.authenticate(secret)
  end

  test "rejects revoked, unknown and validation API tokens" do
    token = build_token
    secret = token.generate_secret
    token.save!

    assert_nil AnalyticsApiToken.authenticate(secret.chop + "x")
    assert_nil AnalyticsApiToken.authenticate("lp_live_validacao_#{SecureRandom.hex(8)}")
    token.revoke!(by: users(:one))
    assert_nil AnalyticsApiToken.authenticate(secret)
  end

  test "records the last use at most once a minute" do
    token = build_token
    token.generate_secret
    token.save!
    now = Time.current

    token.touch_last_used!(now: now)
    token.touch_last_used!(now: now + 30.seconds)
    assert_in_delta now, token.reload.last_used_at, 1.second
    token.touch_last_used!(now: now + 2.minutes)
    assert_in_delta now + 2.minutes, token.reload.last_used_at, 1.second
  end

  test "limits active tokens per account" do
    AnalyticsApiToken::ACTIVE_LIMIT.times { build_token.tap(&:generate_secret).save! }

    extra = build_token.tap(&:generate_secret)
    assert_not extra.valid?
  end

  private

  def build_token
    @account.analytics_api_tokens.new(name: "Power BI", created_by: users(:one))
  end
end
