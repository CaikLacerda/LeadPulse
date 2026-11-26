require "test_helper"

class MobileApiTest < ActionDispatch::IntegrationTest
  include MobileApiStub

  setup do
    @user = users(:one)
    @account = accounts(:one)
    @account.update!(validation_api_token: "tkn_live_company_one")
    Api::V1::Mobile::BaseController::RATE_LIMIT_STORE.clear
    @session = MobileSession.issue!(user: @user, account: @account)
    @headers = { "Authorization" => "Bearer #{@session.token}" }
  end

  test "login returns personal token and oldest active membership without integration secret" do
    other = AccountMembership.create!(user: @user, account: accounts(:two), role: "viewer")
    other.update_column(:created_at, 1.day.from_now)
    post api_v1_mobile_session_path, params: { email: @user.email.upcase, password: "Password123!" }, as: :json
    assert_response :created
    body = response.parsed_body
    assert body["token"].start_with?("lpm_")
    assert_equal @account.name, body.dig("account", "name")
    assert_equal "admin", body["role"]
    assert_equal true, body["can_view_evidence"]
    refute_includes response.body, "tkn_live_"
    session = MobileSession.authenticate(body["token"])
    assert_in_delta 30.days, session.expires_at - Time.current, 5
    refute_equal body["token"], session.token_digest
  end

  test "unknown email and wrong password have the same response" do
    post api_v1_mobile_session_path, params: { email: @user.email, password: "wrong" }, as: :json
    assert_response :unauthorized
    wrong = response.parsed_body
    post api_v1_mobile_session_path, params: { email: "missing@example.test", password: "wrong" }, as: :json
    assert_response :unauthorized
    assert_equal wrong, response.parsed_body
  end

  test "inactive membership denies login and existing session" do
    @user.account_memberships.update_all(status: "disabled")
    post api_v1_mobile_session_path, params: { email: @user.email, password: "Password123!" }, as: :json
    assert_response :forbidden
    get api_v1_mobile_dashboard_path, headers: @headers
    assert_response :forbidden
  end

  test "expired and foreign tokens are refused" do
    @session.update!(expires_at: 1.second.ago)
    [ @session.token, "lpbi_secret", "tkn_live_company_one", "lpm_unknown", "" ].each do |token|
      get api_v1_mobile_dashboard_path, headers: { "Authorization" => "Bearer #{token}" }
      assert_response :unauthorized
    end
  end

  test "password change revokes sessions" do
    @user.update!(password: "NewPassword123!", password_confirmation: "NewPassword123!")
    get api_v1_mobile_dashboard_path, headers: @headers
    assert_response :unauthorized
  end

  test "logout revokes the token" do
    assert_difference "MobileSession.count", -1 do
      delete api_v1_mobile_session_path, headers: @headers
      assert_response :no_content
    end
    get api_v1_mobile_dashboard_path, headers: @headers
    assert_response :unauthorized
  end

  test "login has an IP rate limit" do
    10.times do
      post api_v1_mobile_session_path, params: { email: "missing@example.test", password: "wrong" }, as: :json
      assert_response :unauthorized
    end
    post api_v1_mobile_session_path, params: { email: "missing@example.test", password: "wrong" }, as: :json
    assert_response :too_many_requests
    assert_equal "180", response.headers["Retry-After"]
  end

  test "API has a rate limit" do
    120.times { get api_v1_mobile_dashboard_path }
    get api_v1_mobile_dashboard_path
    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "invalid period and pagination are rejected" do
    get api_v1_mobile_dashboard_path, params: { period: "year" }, headers: @headers
    assert_response :bad_request
    [ { limit: 0 }, { limit: 201 }, { limit: "1.5" }, { offset: -1 }, { offset: "bad" } ].each do |params|
      get api_v1_mobile_calls_path, params:, headers: @headers
      assert_response :bad_request
    end
  end

  test "missing integration does not invalidate the user session" do
    @account.update!(validation_api_token: nil)
    get api_v1_mobile_dashboard_path, headers: @headers
    assert_response :conflict
    assert_equal "integration_not_configured", response.parsed_body.dig("error", "code")
    assert MobileSession.authenticate(@session.token)
  end

  test "dashboard paginates series in Sao Paulo and only returns aggregate fields" do
    offsets = []
    pages = lambda do |api_token:, period:, limit:, offset:|
      assert_equal "tkn_live_company_one", api_token
      assert_equal "week", period
      assert_equal 200, limit
      offsets << offset
      { "total" => 201, "items" => Array.new(offset.zero? ? 200 : 1) { call_item } }
    end
    stub_mobile_api(dashboard: dashboard_payload, calls: pages) do
      get api_v1_mobile_dashboard_path, params: { period: "week" }, headers: @headers
    end
    assert_response :success
    assert_equal [ 0, 200 ], offsets
    body = response.parsed_body
    assert_equal %w[generated_at period series summary window_end window_start], body.keys.sort
    points = body.dig("series", "points")
    bucket = points.find { |point| point["at"] == "2026-10-14T03:00:00Z" }
    assert_equal 201, bucket["attempts"]
    assert_equal 201, bucket["answered"]
    assert points.any? { |point| point["attempts"].zero? }
    assert_equal false, body.dig("series", "truncated")
    assert_equal "2026-10-16T15:00:00.000000Z", body["window_end"]
    refute_includes response.body, "phone"
  end

  test "series is bounded and reports truncated and undated calls" do
    pages = 0
    calls = lambda do |**_|
      pages += 1
      { "total" => 2001, "items" => Array.new(200) { call_item.merge("started_at" => nil, "finished_at" => nil) } }
    end
    stub_mobile_api(dashboard: dashboard_payload, calls:) do
      get api_v1_mobile_dashboard_path, params: { period: "week" }, headers: @headers
    end
    assert_response :success
    assert_equal 10, pages
    assert_equal true, response.parsed_body.dig("series", "truncated")
    assert_equal 2000, response.parsed_body.dig("series", "undated_calls")
  end

  test "hourly buckets respect UTC timestamps without timezone and window boundaries" do
    payload = dashboard_payload.merge("period" => "24h", "window_start" => "2026-10-15T15:00:00")
    calls = [ call_item.merge("started_at" => "2026-10-16T02:15:00"),
      call_item.merge("started_at" => "2026-10-16T15:00:01") ]
    stub_mobile_api(dashboard: payload, calls: { "total" => 2, "items" => calls }) do
      get api_v1_mobile_dashboard_path, params: { period: "24h" }, headers: @headers
    end
    assert_response :success
    points = response.parsed_body.dig("series", "points")
    assert_equal 1, points.sum { |point| point["attempts"] }
    assert_equal 1, points.find { |point| point["at"] == "2026-10-16T02:00:00Z" }["answered"]
  end

  test "upstream errors use safe Portuguese messages and never return personal 401" do
    { 401 => [ 409, "integration_token_invalid" ], 403 => [ 409, "integration_token_invalid" ],
      408 => [ 504, "integration_timeout" ], 429 => [ 503, "integration_rate_limited" ],
      500 => [ 502, "integration_unavailable" ], nil => [ 502, "integration_unavailable" ] }.each do |status, expected|
      error = ValidationApi::Error.new("secret phone tkn_live_leaked", status_code: status)
      stub_mobile_api(dashboard: error) { get api_v1_mobile_dashboard_path, headers: @headers }
      assert_response expected.first
      assert_equal expected.last, response.parsed_body.dig("error", "code")
      refute_includes response.body, "leaked"
    end
  end

  test "invalid upstream data returns safe error" do
    stub_mobile_api(dashboard: { "detail" => "secret" }) do
      get api_v1_mobile_dashboard_path, headers: @headers
    end
    assert_response :bad_gateway
    assert_equal "integration_invalid_response", response.parsed_body.dig("error", "code")
  end

  test "viewer cannot read calls" do
    change_role!(@user, "viewer")
    get api_v1_mobile_calls_path, headers: @headers
    assert_response :forbidden
  end

  test "calls use the session company token and remove all private fields" do
    calls = lambda do |api_token:, **_|
      assert_equal "tkn_live_company_one", api_token
      dashboard_payload.merge("total" => 1, "items" => [ call_item ])
    end
    # The same user also belongs to another company; the session pins the selected company.
    accounts(:two).update!(validation_api_token: "tkn_live_other")
    AccountMembership.create!(user: @user, account: accounts(:two), role: "admin")
    stub_mobile_api(calls:) do
      get api_v1_mobile_calls_path, params: { period: "week" }, headers: @headers
    end
    assert_response :success
    item = response.parsed_body["items"].first
    assert_equal %w[attempt_number client_name duration_seconds finished_at result started_at status], item.keys.sort
    assert_equal "2026-10-15T01:15:00.000000Z", item["started_at"]
  end

  test "mobile requests propagate their request id to the integration context" do
    calls = lambda do |**_|
      assert_equal "phase0-mobile-request", Current.request_id
      dashboard_payload.merge("total" => 1, "items" => [ call_item ])
    end
    stub_mobile_api(calls:) do
      get api_v1_mobile_calls_path, params: { period: "week" }, headers: @headers.merge("X-Request-ID" => "phase0-mobile-request")
    end
    assert_response :success
  end

  private

  def dashboard_payload
    { "period" => "week", "window_start" => "2026-10-09T15:00:00", "window_end" => "2026-10-16T15:00:00",
      "generated_at" => "2026-10-16T15:00:00", "recent_calls" => [ call_item ],
      "summary" => Api::V1::Mobile::DashboardController::SUMMARY_FIELDS.index_with { 0 } }
  end

  def call_item
    { "client_name" => "Cliente Exemplo", "attempt_number" => 1, "status" => "answered", "result" => "confirmed",
      "duration_seconds" => 30, "started_at" => "2026-10-15T01:15:00", "finished_at" => nil,
      "phone_dialed" => "+5511999999999", "observation" => "segredo", "external_id" => "interno" }
  end
end
