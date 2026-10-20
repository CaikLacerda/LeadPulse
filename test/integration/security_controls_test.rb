require "test_helper"

class SecurityControlsTest < ActionDispatch::IntegrationTest
  test "login permits a legitimate user and bounds repeated normalized identities" do
    user = create_member!(name: "Security", email: "security@example.test")
    5.times do
      post user_session_path, params: { user: { email: " SECURITY@example.test ", password: "wrong" } }, env: { "REMOTE_ADDR" => "192.0.2.10" }
      assert_not_equal 429, response.status
    end
    post user_session_path, params: { user: { email: user.email, password: "wrong" } }, env: { "REMOTE_ADDR" => "192.0.2.10" }
    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
    # No global account lockout: the victim can still sign in from another IP.
    post user_session_path, params: { user: { email: user.email, password: TenancyTestHelpers::DEFAULT_PASSWORD } }, env: { "REMOTE_ADDR" => "192.0.2.11" }
    assert_response :redirect
    assert_equal user.id, controller.current_user.id
  end

  test "rotating usernames cannot bypass the IP budget and window expires" do
    20.times do |i|
      post user_session_path, params: { user: { email: "missing#{i}@example.test", password: "wrong" } }
    end
    post user_session_path, params: { user: { email: "new@example.test", password: "wrong" } }
    assert_response :too_many_requests
    travel 6.minutes do
      post user_session_path, params: { user: { email: "new@example.test", password: "wrong" } }
      assert_not_equal 429, response.status
    end
  end

  test "password recovery is limited separately and invitation page remains usable" do
    6.times { post user_password_path, params: { user: { email: "missing@example.test" } } }
    assert_response :too_many_requests
    get new_user_session_path
    assert_response :success
    get invitation_path(token: "fake-invitation")
    assert_not_equal 429, response.status
  end

  test "CSP is report only with nonce and mapped asset origins" do
    get new_user_session_path
    policy = response.headers["Content-Security-Policy-Report-Only"]
    assert_includes policy, "https://unpkg.com"
    assert_includes policy, "https://fonts.googleapis.com"
    assert_match(/'nonce-[^']+'/, policy)
    assert_not_includes policy, "unsafe-eval"
    assert_not_includes policy, "unsafe-inline"
    assert_nil response.headers["Content-Security-Policy"]
  end

  test "CSP reports accept bounded JSON and reject invalid payloads" do
    post "/csp-reports", params: { "csp-report" => { "effective-directive" => "script-src-elem", "document-uri" => "https://example.test/?secret=hidden" } }, as: :json
    assert_response :no_content
    post "/csp-reports", params: "{" + "x" * 16_384, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :content_too_large
  end
end
