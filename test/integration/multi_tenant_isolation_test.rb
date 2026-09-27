require "test_helper"

# Isolamento entre empresas pela interface:
#
#   Empresa A ── A1 (admin), A2 (operator)
#   Empresa B ── B1 (admin)
#
# A1 e A2 trabalham sobre os mesmos dados; B1 não lê nem altera nada da empresa A,
# nem pelas listagens nem por URLs e IDs manipulados.
class MultiTenantIsolationTest < ActionDispatch::IntegrationTest
  PASSWORD = TenancyTestHelpers::DEFAULT_PASSWORD

  setup do
    @account_a = Account.create!(name: "Empresa A", validation_api_token: Account.encrypt_validation_api_token("tkn_empresa_a"))
    @account_b = Account.create!(name: "Empresa B", validation_api_token: Account.encrypt_validation_api_token("tkn_empresa_b"))

    @a1 = create_member!(name: "Ana A1", email: "a1@empresa-a.test", account: @account_a, role: "admin")
    @a2 = create_member!(name: "Artur A2", email: "a2@empresa-a.test", account: @account_a, role: "operator")
    @b1 = create_member!(name: "Bruno B1", email: "b1@empresa-b.test", account: @account_b, role: "admin")

    @import_a = create_import(@account_a, @a1, supplier_name: "Fornecedor Exclusivo A")
    @import_b = create_import(@account_b, @b1, supplier_name: "Fornecedor Exclusivo B")

    @search_a = @account_a.supplier_discovery_searches.create!(
      user: @a1,
      search_id: "search-empresa-a",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Segmento Exclusivo A",
      results_filename: "busca-a.xlsx",
      results_xlsx_data: "planilha-a"
    )
    @opportunity_a = @account_a.commercial_opportunities.create!(
      user: @a1,
      supplier_import: @import_a,
      source_external_id: "a-1",
      supplier_name: "Retorno Exclusivo A",
      callback_phone: "+5511987654321",
      status: CommercialOpportunity::STATUS_COMPLETED,
      result_ready: true
    )
    @privacy_request_a = @account_a.privacy_requests.create!(
      user: @a1,
      request_type: "access",
      subject_name: "Titular Exclusivo A",
      subject_contact: "titular@empresa-a.test"
    )
    @operator_a = @account_a.third_party_operators.create!(
      user: @a1,
      name: "Operador Exclusivo A",
      service_type: "telephony"
    )
  end

  test "A1 and A2 work on the same account data" do
    import_by_a2 = create_import(@account_a, @a2, supplier_name: "Criado por A2")

    [ @a1, @a2 ].each do |member|
      sign_in_as(member)

      get supplier_imports_url
      assert_response :success
      assert_includes response.body, @import_a.display_code
      assert_includes response.body, import_by_a2.display_code
      assert_not_includes response.body, @import_b.display_code

      get supplier_import_url(@import_a)
      assert_response :success
      assert_includes response.body, "Fornecedor Exclusivo A"

      get commercial_opportunities_url
      assert_includes response.body, "Retorno Exclusivo A"

      sign_out_current
    end
  end

  test "A2 keeps the operator permissions inside account A" do
    sign_in_as(@a2)

    get company_platform_settings_url
    assert_redirected_to root_url

    assert_no_difference -> { SupplierImport.count } do
      delete supplier_import_url(@import_a)
    end
    assert_redirected_to supplier_imports_url

    get validation_audits_url
    assert_response :success
    assert_includes response.body, "Fornecedor Exclusivo A"
  end

  test "B1 does not see account A data in any listing" do
    sign_in_as(@b1)

    [
      root_url,
      supplier_imports_url,
      supplier_discovery_searches_url,
      commercial_opportunities_url,
      validation_audits_url,
      privacy_requests_url,
      third_party_operators_url,
      privacy_audit_events_url
    ].each do |url|
      get url
      assert_response :success, url

      body = response.body
      assert_not_includes body, @import_a.display_code, url
      assert_not_includes body, "Fornecedor Exclusivo A", url
      assert_not_includes body, "Segmento Exclusivo A", url
      assert_not_includes body, "Retorno Exclusivo A", url
      assert_not_includes body, "Titular Exclusivo A", url
      assert_not_includes body, "Operador Exclusivo A", url
    end
  end

  test "B1 gets not found for account A records through manipulated URLs" do
    sign_in_as(@b1)

    requests = [
      [ :get, supplier_import_url(@import_a) ],
      [ :post, start_validation_supplier_import_url(@import_a) ],
      [ :post, sync_status_supplier_import_url(@import_a) ],
      [ :post, sync_status_supplier_import_url(@import_a, format: :json) ],
      [ :post, anonymize_evidence_supplier_import_url(@import_a) ],
      [ :get, export_result_supplier_import_url(@import_a) ],
      [ :get, export_result_supplier_import_url(@import_a, format: :xlsx) ],
      [ :get, privacy_report_supplier_import_url(@import_a) ],
      [ :delete, supplier_import_url(@import_a) ],
      [ :get, commercial_opportunity_url(@opportunity_a) ],
      [ :post, start_commercial_opportunity_url(@opportunity_a) ],
      [ :post, sync_status_commercial_opportunity_url(@opportunity_a) ],
      [ :get, export_commercial_opportunity_url(@opportunity_a) ],
      [ :get, download_results_supplier_discovery_search_url(@search_a) ],
      [ :post, create_segment_import_supplier_discovery_search_url(@search_a) ],
      [ :post, retry_search_supplier_discovery_search_url(@search_a) ],
      [ :patch, privacy_request_url(@privacy_request_a), { privacy_request: { status: "resolved", resolution: "Invasão" } } ],
      [ :patch, third_party_operator_url(@operator_a), { third_party_operator: { name: "Invasão" } } ],
      [ :delete, third_party_operator_url(@operator_a) ]
    ]

    requests.each do |method, url, params|
      public_send(method, url, params: params || {})
      assert_response :not_found, "#{method.upcase} #{url}"
    end

    assert SupplierImport.exists?(@import_a.id)
    assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, @import_a.reload.status
    assert_equal "open", @privacy_request_a.reload.status
    assert_equal "Operador Exclusivo A", @operator_a.reload.name
    assert @operator_a.active?
    assert_equal 1, @account_a.supplier_imports.count
  end

  test "B1 cannot attach reviews or privacy requests to an account A batch" do
    sign_in_as(@b1)

    assert_no_difference -> { AuditReview.count } do
      post validation_audit_reviews_url, params: {
        audit_review: {
          supplier_import_id: @import_a.id,
          record_external_id: "a-1",
          original_result: "confirmed_by_call",
          reviewed_result: "wrong_company"
        }
      }
    end
    assert_response :not_found

    assert_no_difference -> { PrivacyRequest.count } do
      post privacy_requests_url, params: {
        privacy_request: {
          request_type: "access",
          subject_name: "Titular",
          subject_contact: "titular@empresa-b.test",
          supplier_import_id: @import_a.id
        }
      }
    end
    assert_response :not_found
  end

  test "each account sees only its own settings and audit trail" do
    @account_a.update!(validation_company_name: "Razão Social A")
    @account_b.update!(validation_company_name: "Razão Social B")
    PrivacyAudit::Logger.log!(account: @account_a, user: @a1, action: "supplier_import_result_exported", supplier_import: @import_a)

    sign_in_as(@b1)

    get company_platform_settings_url
    assert_includes response.body, "Razão Social B"
    assert_not_includes response.body, "Razão Social A"

    get privacy_audit_events_url
    assert_not_includes response.body, @import_a.display_code
  end

  test "settings changed by A1 apply to A2 and never to B1" do
    sign_in_as(@a1)
    patch lgpd_platform_settings_url, params: { account: { lgpd_evidence_retention_days: 45 } }
    sign_out_current

    assert_equal 45, @account_a.reload.lgpd_evidence_retention_days
    assert_equal 180, @account_b.reload.lgpd_evidence_retention_days
  end

  test "a disabled member loses access to the account" do
    membership_of(@a2).disable!

    sign_in_as(@a2)
    get supplier_imports_url

    assert_redirected_to new_user_session_url
  end

  test "signs out a user who does not belong to any account" do
    orphan = User.create!(name: "Sem empresa", email: "orfao@example.test", password: PASSWORD, password_confirmation: PASSWORD)
    sign_in_as(orphan)

    get supplier_imports_url

    assert_redirected_to new_user_session_url
    follow_redirect!
    assert_match "não está vinculado a nenhuma empresa", response.body
  end

  private

  def create_import(account, user, supplier_name:)
    account.supplier_imports.create!(
      user: user,
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 0,
      remote_batch_id: "batch-#{SecureRandom.hex(4)}",
      validation_started_at: 1.day.ago,
      result_ready: true,
      response_payload: {
        "records" => [
          {
            "external_id" => "#{supplier_name.parameterize}-1",
            "client_name" => supplier_name,
            "phone_normalized" => "+5511900000000",
            "final_status" => "validated",
            "call_result" => "confirmed",
            "call_attempts" => [ { "attempt_number" => 1, "status" => "answered", "result" => "confirmed" } ]
          }
        ]
      }
    )
  end

  def sign_in_as(user)
    post user_session_url, params: { user: { email: user.email, password: PASSWORD } }
  end

  def sign_out_current
    delete destroy_user_session_url
  end
end
