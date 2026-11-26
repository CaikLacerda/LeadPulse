require "test_helper"

# Drill-down do Analytics: cada número leva aos itens que o compõem, com os mesmos filtros e
# definições, só para quem pode ver registros e só dentro da empresa.
class AnalyticsDrillTest < ActionDispatch::IntegrationTest
  PASSWORD = TenancyTestHelpers::DEFAULT_PASSWORD

  setup do
    @account_a = Account.create!(name: "Empresa A")
    @account_b = Account.create!(name: "Empresa B")
    @admin = create_member!(name: "Ana", email: "ana@drill-a.test", account: @account_a, role: "admin")
    @viewer = create_member!(name: "Vera", email: "vera@drill-a.test", account: @account_a, role: "viewer")
    @admin_b = create_member!(name: "Bruno", email: "bruno@drill-b.test", account: @account_b, role: "admin")

    friday = Date.current.prev_occurring(:friday).in_time_zone("America/Sao_Paulo").change(hour: 15, min: 10)
    records = Array.new(3) { |index| analytics_record("inconclusive", client_name: "Inconclusivo #{index}", attempts: [ analytics_attempt("answered", started_at: friday + index.minutes) ]) } +
      Array.new(2) { |index| analytics_record("confirmed", client_name: "Confirmado #{index}", attempts: [ analytics_attempt("answered", started_at: friday.change(hour: 9)) ]) }
    @lot = create_analytics_batch!(account: @account_a, user: @admin, started_at: friday - 1.hour, records: records)
    @lot_b = create_analytics_batch!(account: @account_b, user: @admin_b, started_at: friday - 1.hour, records: [ analytics_record("inconclusive", client_name: "Segredo B") ])
  end

  test "records behind a result, with the count matching the chart" do
    sign_in_as(@admin)

    get records_analytics_url(resultado: "inconclusive")

    assert_response :success
    assert_select ".analytics-drill-header__count", text: "3 registros"
    assert_select "tbody tr", count: 3
    assert_select "tbody", text: /Inconclusivo 0/
    assert_not_includes response.body, "Confirmado 0"
    assert_select ".analytics-chip", text: /Resultado: Inconclusivo/
    assert_select "a[href='#{supplier_import_path(@lot)}']", minimum: 1
    assert_not_includes response.body, "Segredo B"
  end

  test "attempts behind a heatmap cell" do
    sign_in_as(@admin)

    get attempts_analytics_url(dia_semana: 5, hora: 15)

    assert_response :success
    assert_select ".analytics-drill-header__count", text: "3 tentativas"
    assert_select ".analytics-chip", text: /Dia: Sexta-feira/
    assert_select ".analytics-chip", text: /Hora: 15h–16h/
  end

  test "attempts behind a duration bin" do
    started_at = Date.current.prev_occurring(:friday).in_time_zone("America/Sao_Paulo").change(hour: 11)
    create_analytics_batch!(account: @account_a, user: @admin, started_at: started_at - 1.hour, records: [
      analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: started_at, duration: 45) ]),
      analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: started_at, duration: 90) ])
    ])
    sign_in_as(@admin)

    get attempts_analytics_url(duracao: "30s_1m")

    assert_response :success
    assert_select ".analytics-drill-header__count", text: "1 tentativa"
    assert_select ".analytics-chip", text: /Duração: 30–60 s/
  end

  test "pages through records with a cursor" do
    lot = create_analytics_batch!(account: @account_a, user: @admin, started_at: 2.days.ago, records: analytics_records(not_answered: 30))
    sign_in_as(@admin)

    get records_analytics_url(lote: lot.id)
    assert_select "tbody tr", count: 25
    next_link = css_select("a[rel='next']").first["href"]

    get next_link
    assert_select "tbody tr", count: 5
    assert_select "a[rel='next']", count: 0
  end

  test "values outside the allowlist are ignored" do
    sign_in_as(@admin)

    get records_analytics_url(resultado: "' OR 1=1 --", qualificacao: "DROP TABLE")

    assert_response :success
    assert_select ".analytics-drill-header__count", text: "5 registros"
    assert_select ".analytics-chip", count: 0
  end

  test "profiles without evidence access do not open the lists nor see links" do
    sign_in_as(@viewer)

    get records_analytics_url(resultado: "inconclusive")
    assert_redirected_to analytics_url

    get analytics_url
    assert_select "a[href*='/analytics/registros'], a[href*='/analytics/tentativas']", count: 0
    assert_select ".analytics-funnel a", count: 0
  end

  test "another company cannot reach the lot through the drill-down" do
    sign_in_as(@admin_b)

    get records_analytics_url(lote: @lot.id)

    assert_select ".analytics-drill-header__count", text: "1 registro"
    assert_not_includes response.body, "Inconclusivo 0"
  end

  private

  def sign_in_as(user)
    post user_session_url, params: { user: { email: user.email, password: PASSWORD } }
  end
end
