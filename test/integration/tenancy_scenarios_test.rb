require "test_helper"
require "csv"

# Cenário obrigatório do tenancy por empresa:
#
#   Empresa A ── Admin A, Operator A
#   Empresa B ── Admin B, Viewer B
#
# Membros da mesma empresa veem os mesmos dados (conforme o papel); nenhum deles alcança a
# outra empresa, nem por tela, URL, exportação, API de BI ou cache.
class TenancyScenariosTest < ActionDispatch::IntegrationTest
  PASSWORD = TenancyTestHelpers::DEFAULT_PASSWORD

  setup do
    @account_a = Account.create!(name: "Empresa A", validation_company_name: "Razão Social A")
    @account_b = Account.create!(name: "Empresa B", validation_company_name: "Razão Social B")
    @admin_a = create_member!(name: "Admin A", email: "admin@a.test", account: @account_a, role: "admin")
    @operator_a = create_member!(name: "Operator A", email: "operator@a.test", account: @account_a, role: "operator")
    @admin_b = create_member!(name: "Admin B", email: "admin@b.test", account: @account_b, role: "admin")
    @viewer_b = create_member!(name: "Viewer B", email: "viewer@b.test", account: @account_b, role: "viewer")

    # Nomes gerados em tempo de execução: só aparecem numa resposta se o dado vazou.
    @secret_a = "Fornecedor-A-#{SecureRandom.hex(4)}"
    @secret_b = "Fornecedor-B-#{SecureRandom.hex(4)}"
    @lot_a = seed_company(@account_a, @admin_a, @secret_a, 3)
    @lot_b = seed_company(@account_b, @admin_b, @secret_b, 2)
    @token_a = bi_token(@account_a, @admin_a)
    @token_b = bi_token(@account_b, @admin_b)
    @invitation_a = Accounts::TeamManagement.new(account: @account_a, actor: @admin_a).invite(email: "novo@a.test", role: "viewer").record
  end

  test "Admin A and Operator A share the data of company A" do
    [ @admin_a, @operator_a ].each do |member|
      sign_in_as(member)

      { root_path => @lot_a.display_code, supplier_imports_path => @lot_a.display_code,
        supplier_discovery_searches_path => "Segmento de Empresa A", commercial_opportunities_path => "Retorno de Empresa A",
        validation_audits_path => @secret_a, team_path => "Operator A" }.each do |path, content|
        get path
        assert_response :success, "#{member.name} em #{path}"
        assert_includes response.body, content, "#{member.name} em #{path}"
        assert_not_includes response.body, @secret_b
      end

      get analytics_path
      assert_select "[data-metric='records'] .workspace-metric-card__value", text: "3"

      sign_out_current
    end
  end

  test "Admin B and Viewer B only see company B" do
    [ @admin_b, @viewer_b ].each do |member|
      sign_in_as(member)

      [ root_path, supplier_imports_path, supplier_discovery_searches_path, commercial_opportunities_path,
        analytics_path, calls_analytics_path, qualification_analytics_path, batches_analytics_path, team_path ].each do |path|
        get path
        assert_response :success, "#{member.name} em #{path}"
        [ @lot_a.display_code, @secret_a, "Empresa A", "Operator A", "novo@a.test" ].each do |secret|
          assert_not_includes response.body, secret, "#{member.name} em #{path}"
        end
      end

      get analytics_path
      assert_select "[data-metric='records'] .workspace-metric-card__value", text: "2"

      sign_out_current
    end
  end

  test "manipulated ids from company A are not found for company B" do
    [ @admin_b, @viewer_b ].each do |member|
      sign_in_as(member)

      [
        [ :get, supplier_import_path(@lot_a) ],
        [ :get, export_result_supplier_import_path(@lot_a) ],
        [ :delete, supplier_import_path(@lot_a) ],
        [ :get, commercial_opportunity_path(@account_a.commercial_opportunities.first) ],
        [ :get, download_results_supplier_discovery_search_path(@account_a.supplier_discovery_searches.first) ],
        [ :patch, team_member_path(membership_of(@operator_a)), { account_membership: { role: "admin" } } ],
        [ :delete, team_invitation_path(@invitation_a) ],
        [ :delete, analytics_api_token_path(@token_a) ]
      ].each do |method, path, params|
        public_send(method, path, params: params || {})
        assert_includes [ 302, 404 ], response.status, "#{member.name}: #{method} #{path}"
        assert_not_includes response.body.to_s, @secret_a
      end

      get analytics_path(lote: @lot_a.id)
      assert_select "[data-metric='records'] .workspace-metric-card__value", text: "2"

      sign_out_current
    end

    assert SupplierImport.exists?(@lot_a.id)
    assert_equal "operator", membership_of(@operator_a).reload.role
    assert @invitation_a.reload.pending?
    assert @token_a.reload.active?
  end

  test "exports and BI only carry the company data" do
    sign_in_as(@admin_b)
    get export_analytics_path(format: :csv, conjunto: "registros")
    codes = CSV.parse(response.body.delete_prefix("﻿"), headers: true).map { |row| row["batch_code"] }.uniq
    assert_equal [ @lot_b.display_code ], codes

    get export_analytics_path(format: :xlsx)
    Tempfile.create([ "b", ".xlsx" ]) do |file|
      file.binmode
      file.write(response.body)
      file.flush
      lots = Roo::Spreadsheet.open(file.path, extension: :xlsx).sheet("Lotes")
      assert_equal [ @lot_b.display_code ], (2..lots.last_row).map { |row| lots.cell(row, 1) } - [ "Total" ]
    end
    sign_out_current

    { @token_a => @lot_a, @token_b => @lot_b }.each do |token, lot|
      %w[records calls batches].each do |endpoint|
        get "/api/v1/analytics/#{endpoint}", headers: { "Authorization" => "Bearer #{token.token}" }
        assert_response :success
        assert_equal [ lot.display_code ], JSON.parse(response.body)["data"].map { |row| row["batch_code"] }.uniq, endpoint
      end
    end
  end

  test "the Analytics cache never mixes companies" do
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    begin
      sign_in_as(@admin_a)
      get analytics_path
      sign_out_current

      sign_in_as(@viewer_b)
      get analytics_path
      assert_select "[data-metric='records'] .workspace-metric-card__value", text: "2"
      sign_out_current

      sign_in_as(@operator_a)
      get analytics_path
      assert_select "[data-metric='records'] .workspace-metric-card__value", text: "3"
    ensure
      Rails.cache = original
    end
  end

  test "integrations, team and invitations belong to each company" do
    sign_in_as(@admin_b)
    get company_platform_settings_path
    assert_includes response.body, "Razão Social B"
    assert_not_includes response.body, "Razão Social A"

    get analytics_api_tokens_path
    assert_includes response.body, @token_b.token_prefix
    assert_not_includes response.body, @token_a.token_prefix

    token = @invitation_a.regenerate_token
    @invitation_a.save!
    post accept_invitation_path(token)
    assert_not AccountMembership.exists?(account: @account_a, user: @admin_b), "convite é do e-mail convidado, não de quem clica"
  end

  private

  def seed_company(account, admin, supplier_name, records)
    lot = create_analytics_batch!(
      account: account, user: admin, started_at: 1.day.ago.change(hour: 10), result_ready: true,
      records: Array.new(records) do |index|
        analytics_record("confirmed", client_name: supplier_name, external_id: "#{account.id}-#{index}",
          attempts: [ analytics_attempt("answered", started_at: 1.day.ago.change(hour: 10), duration: 20) ])
      end
    )
    company = account.name
    account.supplier_discovery_searches.create!(created_by: admin, search_id: "search-#{account.id}", status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Segmento de #{company}", results_filename: "busca.xlsx", results_xlsx_data: "planilha")
    account.commercial_opportunities.create!(supplier_import: lot, source_external_id: "#{account.id}-0", supplier_name: "Retorno de #{company}", callback_phone: "+5511987654321")
    lot
  end

  def bi_token(account, user)
    account.analytics_api_tokens.new(name: "BI #{account.name}", created_by: user).tap(&:generate_secret).tap(&:save!)
  end

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: PASSWORD } }
  end

  def sign_out_current
    delete destroy_user_session_path
  end
end
