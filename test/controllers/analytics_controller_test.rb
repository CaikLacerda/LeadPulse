require "test_helper"
require "csv"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = TenancyTestHelpers::DEFAULT_PASSWORD

  setup do
    @account_a = Account.create!(name: "Empresa A")
    @account_b = Account.create!(name: "Empresa B")
    @admin_a = create_member!(name: "Ana A1", email: "a1@analytics-page-a.test", account: @account_a)
    @viewer_a = create_member!(name: "Vera A2", email: "a2@analytics-page-a.test", account: @account_a, role: "viewer")
    @admin_b = create_member!(name: "Bruno B1", email: "b1@analytics-page-b.test", account: @account_b)

    started_at = 2.days.ago.change(hour: 10)
    @batch_a = create_analytics_batch!(account: @account_a, user: @admin_a, started_at: started_at, records: analytics_records(confirmed: 5, rejected: 3))
    @batch_b = create_analytics_batch!(account: @account_b, user: @admin_b, started_at: started_at, records: analytics_records(not_answered: 2))
  end

  test "visitors are sent to the login" do
    get analytics_url

    assert_redirected_to new_user_session_url
  end

  test "every role sees the aggregates, with the sample and the low sample flag" do
    sign_in_as(@viewer_a)

    get analytics_url

    assert_response :success
    assert_select "turbo-frame#analytics_content"
    assert_select "[data-metric='records'] .workspace-metric-card__value", text: "8"
    assert_select "[data-metric='confirmation_rate'] .workspace-metric-card__value", text: "62,5%"
    assert_select "[data-metric='confirmation_rate'] .analytics-kpi__sample", text: /n = 8/
    assert_select "[data-metric='confirmation_rate'] .analytics-low-sample", text: "Baixa amostra"
    assert_select ".app-sidebar a[href='#{analytics_path}']"
  end

  test "never shows personal data" do
    sign_in_as(@admin_a)

    get analytics_url(periodo: "12m")

    assert_not_includes response.body, "+5511900000000"
    assert_not_includes response.body, "gravacao"
    assert_not_includes response.body, "Fornecedor"
  end

  test "charts get the same aggregates as their data tables and nothing else" do
    sign_in_as(@admin_a)

    get analytics_url

    charts = css_select("[data-controller='analytics-chart']").to_h do |element|
      [ element["data-analytics-chart-kind-value"], JSON.parse(element["data-analytics-chart-data-value"]) ]
    end
    assert_equal %w[stacked_timeline ranked_bars funnel_bars], charts.keys
    assert_equal 8, charts["ranked_bars"]["values"].sum
    assert_equal [ "62,5%", "37,5%" ], charts["ranked_bars"]["shares"]
    assert_equal 8, charts["stacked_timeline"]["series"].sum { |series| series["values"].sum }
    assert_equal [ 8, 8, 8, 5 ], charts["funnel_bars"]["values"]
    assert_select "#analytics-chart-results table tbody tr", count: 2
    assert_select "#analytics-chart-results [role='img'][aria-label*='Confirmado: 5 (62,5%)']"
    charts.each_value { |data| assert_no_match(/\+55|gravacao|texto|rec-/, data.to_json) }
  end

  test "calls page shows attempts by their own time with the duration coverage" do
    records = [
      analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: 2.days.ago.change(hour: 10), duration: 40) ]),
      analytics_record("not_answered", attempts: [ analytics_attempt("not_answered", started_at: 2.days.ago.change(hour: 11), duration: 0) ])
    ]
    create_analytics_batch!(account: @account_a, user: @admin_a, started_at: 2.days.ago.change(hour: 9), records: records)
    sign_in_as(@viewer_a)

    get calls_analytics_url

    assert_response :success
    assert_select "[data-metric='attempts'] .workspace-metric-card__value", text: "2"
    assert_select "[data-metric='answer_rate'] .workspace-metric-card__value", text: "50,0%"
    assert_select "[data-metric='median_duration'] .workspace-metric-card__value", text: "40 s"
    assert_select "[data-metric='duration_coverage'] .workspace-metric-card__value", text: "100,0%"
    assert_select "[data-analytics-chart-kind-value='hourly_rate']"
    assert_select "a.settings-tab--active[aria-current='page']", text: "Chamadas"
  end

  test "qualification page shows the nested commercial funnel" do
    @batch_a.response_payload["records"].first.then do |record|
      @account_a.commercial_opportunities.create!(user: @admin_a, supplier_import: @batch_a, source_external_id: record["external_id"],
        supplier_name: "Fornecedor", callback_phone: "+5511987654321", status: CommercialOpportunity::STATUS_COMPLETED)
    end
    sign_in_as(@admin_a)

    get qualification_analytics_url

    assert_response :success
    assert_select "[data-metric='qualified'] .workspace-metric-card__value", text: "5"
    assert_select "[data-metric='opportunities'] .workspace-metric-card__value", text: "1"
    funnel = JSON.parse(css_select("#analytics-chart-commercial-funnel")[0]["data-analytics-chart-data-value"])
    assert_equal [ 8, 5, 1, 1 ], funnel["values"]
  end

  test "batches page sorts only by allowed columns and filters by status" do
    other = create_analytics_batch!(account: @account_a, user: @admin_a, started_at: 1.day.ago, records: analytics_records(confirmed: 1),
      status: SupplierImport::LOCAL_STATUS_ERROR)
    sign_in_as(@admin_a)

    get batches_analytics_url(ordem: "registros", direcao: "asc")
    assert_response :success
    codes = css_select(".analytics-batches-table tbody tr td:first-child").map { |cell| cell.text.strip }
    assert_equal [ other.display_code, @batch_a.display_code ], codes
    assert_select "th[aria-sort='ascending']", text: /Registros/

    get batches_analytics_url(ordem: "id; DROP TABLE users", status: "erro")
    assert_response :success
    assert_select ".analytics-batches-table tbody tr", count: 1
    assert_select ".analytics-batches-table tbody", text: /#{other.display_code}/
  end

  test "each page renders its empty state" do
    sign_in_as(@admin_a)

    { calls_analytics_url(periodo: "7d") => "Nenhuma tentativa de chamada no período.",
      batches_analytics_url(periodo: "personalizado", de: "2025-01-01", ate: "2025-01-31") => "Nenhum lote criado no período." }.each do |url, message|
      get url
      assert_response :success
      assert_select ".workspace-empty-state__title", text: message
    end
  end

  test "B only sees B on every page, even with a batch of A in the URL" do
    sign_in_as(@admin_b)

    [ calls_analytics_url(lote: @batch_a.id), qualification_analytics_url(lote: @batch_a.id), batches_analytics_url(lote: @batch_a.id) ].each do |url|
      get url
      assert_response :success, url
      assert_not_includes response.body, @batch_a.display_code, url
    end

    get batches_analytics_url
    assert_select ".analytics-batches-table tbody tr", count: 1
  end

  test "any role exports the spreadsheet; the records sheet needs data export permission" do
    sign_in_as(@viewer_a)

    assert_difference -> { PrivacyAuditEvent.where(action: "analytics_exported").count }, 1 do
      get export_analytics_url(format: :xlsx, fluxo: "supplier_validation")
    end

    assert_response :success
    assert_equal Analytics::XlsxExport::CONTENT_TYPE, response.media_type
    assert_match(/attachment; filename="leadpulse_analytics_\d{4}-\d{2}-\d{2}\.xlsx"/, response.headers["Content-Disposition"])
    event = PrivacyAuditEvent.where(action: "analytics_exported").last
    assert_equal @account_a, event.account
    assert_equal @viewer_a, event.user
    assert_equal({ "fluxo" => "supplier_validation" }, event.metadata["filters"])
    assert_equal [ "Resumo", "Lotes", "Chamadas por dia" ], event.metadata["sheets"]
  end

  test "CSV needs data export permission" do
    sign_in_as(@viewer_a)

    assert_no_difference -> { PrivacyAuditEvent.count } do
      get export_analytics_url(format: :csv, conjunto: "registros")
    end

    assert_redirected_to analytics_url
    assert_equal "Seu perfil não pode exportar dados por registro.", flash[:alert]
  end

  test "CSV streams only the account records and is logged" do
    sign_in_as(@admin_b)

    get export_analytics_url(format: :csv, conjunto: "registros", lote: @batch_a.id)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_equal "no-cache", response.headers["Cache-Control"]
    csv = CSV.parse(response.body.delete_prefix("\uFEFF"), headers: true)
    assert_equal [ @batch_b.display_code ] * 2, csv.map { |row| row["batch_code"] }
    assert_equal "registros", PrivacyAuditEvent.where(action: "analytics_exported").last.metadata["dataset"]
  end

  test "the export menu follows the profile" do
    sign_in_as(@viewer_a)
    get analytics_url(periodo: "90d")
    assert_select ".analytics-export a[href*='exportar.xlsx'][href*='periodo=90d'][data-turbo='false']", count: 1
    assert_select ".analytics-export a[href*='exportar.csv']", count: 0
    sign_out_current

    sign_in_as(@admin_a)
    get analytics_url
    assert_select ".analytics-export a[href*='exportar.csv']", count: 2
  end

  test "B only sees B, even with a batch of A in the URL" do
    sign_in_as(@admin_b)

    get analytics_url(lote: @batch_a.id)

    assert_response :success
    assert_select "[data-metric='records'] .workspace-metric-card__value", text: "2"
    assert_select "select[name='lote'] option[value='#{@batch_a.id}']", count: 0
    assert_select "select[name='lote'] option[value='#{@batch_b.id}']", count: 1
    assert_not_includes response.body, @batch_a.display_code
  end

  test "an empty period shows the empty state" do
    sign_in_as(@admin_a)

    get analytics_url(periodo: "personalizado", de: "2025-01-01", ate: "2025-01-31")

    assert_response :success
    assert_select ".workspace-empty-state__title", text: "Ainda não há dados para este período."
    assert_select ".analytics-kpi", count: 0
  end

  test "a custom period above 366 days is refused with a notice" do
    sign_in_as(@admin_a)

    get analytics_url(periodo: "personalizado", de: "2020-01-01", ate: Date.current.iso8601)

    assert_response :success
    assert_match "O período personalizado aceita até 366 dias", response.body
    assert_select "[data-metric='records'] .workspace-metric-card__value", text: "8"
  end

  private

  def sign_in_as(user)
    post user_session_url, params: { user: { email: user.email, password: PASSWORD } }
  end

  def sign_out_current
    delete destroy_user_session_url
  end
end
