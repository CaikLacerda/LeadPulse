require "test_helper"

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
end
