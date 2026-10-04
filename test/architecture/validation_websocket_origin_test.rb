require "test_helper"

class ValidationWebsocketOriginTest < ActiveSupport::TestCase
  test "derives secure audio origin and rejects unsafe CSP sources" do
    assert_equal "wss://api.example.test", Security::ValidationWebsocketOrigin.value(env: { "VALIDATION_API_BASE_URL" => "https://api.example.test/" }, production: true)
    %w[https://user:password@example.test wss://*.example.test/path wss://example.test?token=secret ws://example.test].each do |url|
      assert_raises(ArgumentError) { Security::ValidationWebsocketOrigin.value(env: { "VALIDATION_API_WS_BASE_URL" => url }, production: true) }
    end
  end

  test "reverse proxy path remains in audio URLs but not in the CSP origin" do
    config = { "VALIDATION_API_WS_BASE_URL" => "wss://api.example.test/gateway/" }
    assert_equal "wss://api.example.test/gateway", Security::ValidationWebsocketOrigin.base_url(env: config, production: true)
    assert_equal "wss://api.example.test", Security::ValidationWebsocketOrigin.value(env: config, production: true)
  end

  test "CSP allows the configured audio origin without enforcing yet" do
    assert Rails.application.config.content_security_policy_report_only
    assert_includes Rails.application.config.content_security_policy.directives["connect-src"], Security::ValidationWebsocketOrigin.value
  end
end
