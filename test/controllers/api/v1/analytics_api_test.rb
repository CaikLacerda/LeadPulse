require "test_helper"

# API de Analytics para BI: token da empresa, somente leitura, isolada por empresa.
class AnalyticsApiTest < ActionDispatch::IntegrationTest
  setup do
    @account_a = Account.create!(name: "Empresa A")
    @account_b = Account.create!(name: "Empresa B")
    @admin_a = create_member!(name: "Ana", email: "ana@api-a.test", account: @account_a, role: "admin")
    @admin_b = create_member!(name: "Bruno", email: "bruno@api-b.test", account: @account_b, role: "admin")

    started = 3.days.ago.change(hour: 10)
    records = Array.new(5) do |index|
      analytics_record(index.even? ? "confirmed" : "not_answered", attempts: [ analytics_attempt(index.even? ? "answered" : "not_answered", started_at: started + index.minutes, duration: 30) ])
    end
    @lot_a1 = create_analytics_batch!(account: @account_a, user: @admin_a, started_at: started, records: records.first(3))
    @lot_a2 = create_analytics_batch!(account: @account_a, user: @admin_a, started_at: started + 1.hour, records: records.last(2), status: SupplierImport::LOCAL_STATUS_ERROR)
    @lot_b = create_analytics_batch!(account: @account_b, user: @admin_b, started_at: started, records: analytics_records(rejected: 4))

    @token_a = create_token(@account_a, @admin_a)
    @token_b = create_token(@account_b, @admin_b)
  end

  test "refuses requests without a valid BI token" do
    get api_v1_analytics_summary_url
    assert_response :unauthorized
    assert_equal 'Bearer realm="LeadPulse Analytics"', response.headers["WWW-Authenticate"]

    get api_v1_analytics_records_url, headers: auth("lpbi_nao_existe")
    assert_response :unauthorized

    @account_a.update!(validation_api_token: Account.encrypt_validation_api_token("lp_live_validacao"))
    get api_v1_analytics_records_url, headers: auth("lp_live_validacao")
    assert_response :unauthorized, "o token da API de validação não serve para BI"

    @token_a.revoke!(by: @admin_a)
    get api_v1_analytics_records_url, headers: auth(@token_a.token)
    assert_response :unauthorized
  end

  test "each token only reads its own company" do
    get api_v1_analytics_records_url, headers: auth(@token_a.token)
    codes_a = json["data"].map { |row| row["batch_code"] }.uniq
    get api_v1_analytics_records_url, headers: auth(@token_b.token)
    codes_b = json["data"].map { |row| row["batch_code"] }.uniq

    assert_equal [ @lot_a1.display_code, @lot_a2.display_code ].sort, codes_a.sort
    assert_equal [ @lot_b.display_code ], codes_b

    get api_v1_analytics_batches_url(batch_id: @lot_b.id), headers: auth(@token_a.token)
    assert_response :not_found
  end

  test "records are paginated by cursor without repeating rows" do
    seen = []
    url = api_v1_analytics_records_url(page: { size: 2 })
    pages = 0
    while url
      get url, headers: auth(@token_a.token)
      assert_response :success
      seen.concat(json["data"].map { |row| [ row["batch_id"], row["record_external_id"] ] })
      url = json.dig("links", "next")
      pages += 1
    end

    assert_equal 3, pages
    assert_equal 5, seen.size
    assert_equal seen.uniq, seen
  end

  test "rows use stable fields, UTC dates and no personal data" do
    get api_v1_analytics_records_url, headers: auth(@token_a.token)
    record = json["data"].first
    assert_equal Analytics::RowPresenter::RECORD_FIELDS, record.keys
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, record["validation_started_at"])

    get api_v1_analytics_calls_url, headers: auth(@token_a.token)
    attempt = json["data"].first
    assert_equal Analytics::RowPresenter::ATTEMPT_FIELDS, attempt.keys
    assert_equal 30, attempt["duration_seconds"]

    [ api_v1_analytics_records_url, api_v1_analytics_calls_url, api_v1_analytics_batches_url ].each do |url|
      get url, headers: auth(@token_b.token)
      assert_no_match(/\+55|gravacao|transcript|texto|phone_normalized/, response.body, url)
    end
  end

  test "summary brings the sample and only conclusive changes" do
    get api_v1_analytics_summary_url, headers: auth(@token_a.token)

    assert_response :success
    records = json.dig("data", "metrics", "records")
    assert_equal 5, records["value"]
    confirmation = json.dig("data", "metrics", "confirmation_rate")
    assert_in_delta 0.6, confirmation["value"]
    assert_equal 5, confirmation["sample"]
    assert confirmation["low_sample"]
    assert_nil confirmation["change"]
    assert_equal "no_base", confirmation["comparison_status"]
    assert_equal 20, json.dig("meta", "min_sample")
  end

  test "batches filter by status and validate parameters" do
    get api_v1_analytics_batches_url(status: "erro"), headers: auth(@token_a.token)
    assert_equal [ @lot_a2.id ], json["data"].map { |row| row["batch_id"] }

    token = create_token(@account_a, @admin_a)
    {
      { from: "2026-01-01" } => "from and to must be sent together.",
      { from: "ontem", to: "hoje" } => "from must be a date in the format YYYY-MM-DD.",
      { from: "2024-01-01", to: "2026-01-01" } => "The period can have at most 366 days.",
      { workflow_kind: "outro" } => "workflow_kind must be one of: cadastral_validation, supplier_validation."
    }.each do |params, message|
      get api_v1_analytics_records_url(params), headers: auth(token.token)
      assert_response :bad_request
      assert_equal message, json.dig("error", "message")
    end
  end

  test "limits page size, rejects bad cursors and rate limits by token" do
    get api_v1_analytics_records_url(page: { size: 10_000 }), headers: auth(@token_a.token)
    assert_equal 500, json.dig("meta", "page_size")

    get api_v1_analytics_records_url(page: { after: "nao-e-cursor" }), headers: auth(@token_a.token)
    assert_response :bad_request

    4.times { get api_v1_analytics_summary_url, headers: auth(@token_a.token) }
    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]

    get api_v1_analytics_summary_url, headers: auth(@token_b.token)
    assert_response :success, "o limite é por token"
  end

  test "records the use of the token once per extraction" do
    assert_difference -> { PrivacyAuditEvent.where(action: "analytics_api_accessed", account: @account_a).count }, 1 do
      get api_v1_analytics_records_url(page: { size: 2 }), headers: auth(@token_a.token)
      get json.dig("links", "next"), headers: auth(@token_a.token)
    end
    event = PrivacyAuditEvent.where(action: "analytics_api_accessed").last
    assert_equal @admin_a, event.user
    assert_equal "records", event.metadata["endpoint"]
    assert @token_a.reload.last_used_at.present?
  end

  private

  def create_token(account, user)
    account.analytics_api_tokens.new(name: "BI", created_by: user).tap(&:generate_secret).tap(&:save!)
  end

  def auth(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def json
    JSON.parse(response.body)
  end
end
