require "test_helper"

# Isolamento entre empresas nos services e models: mesmo chamados diretamente (jobs, console,
# código futuro), eles recusam registros de outra conta.
class MultiTenantServicesTest < ActiveSupport::TestCase
  setup do
    @account_a = Account.create!(name: "Empresa A", validation_api_token: Account.encrypt_validation_api_token("tkn_empresa_a"))
    @account_b = Account.create!(name: "Empresa B", validation_api_token: Account.encrypt_validation_api_token("tkn_empresa_b"))
    @a1 = create_member!(name: "Ana A1", email: "a1@servicos-a.test", account: @account_a, role: "admin")
    @b1 = create_member!(name: "Bruno B1", email: "b1@servicos-b.test", account: @account_b, role: "admin")

    @import_a = @account_a.supplier_imports.create!(
      created_by: @a1,
      status: SupplierImport::LOCAL_STATUS_PROCESSING,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD,
      total_rows: 1,
      valid_rows: 1,
      invalid_rows: 0,
      remote_batch_id: "batch-a",
      validation_started_at: 1.hour.ago,
      response_payload: {
        "records" => [
          {
            "external_id" => "a-1",
            "client_name" => "Fornecedor A",
            "phone_normalized" => "+5511911111111",
            "privacy_refusal_detected" => true,
            "call_attempts" => [ { "attempt_number" => 1, "provider_call_id" => "CA-a", "result" => "confirmed", "customer_transcript" => "Sim" } ]
          }
        ]
      }
    )
    @opportunity_a = @account_a.commercial_opportunities.create!(
      supplier_import: @import_a,
      source_external_id: "a-1",
      supplier_name: "Fornecedor A",
      callback_phone: "+5511987654321",
      remote_batch_id: "commercial-a"
    )
    @search_a = @account_a.supplier_discovery_searches.create!(
      created_by: @a1,
      search_id: "search-a",
      status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
      segment_name: "Ferro"
    )
  end

  test "lot services refuse a lot from another account" do
    assert_raises(ActiveRecord::RecordNotFound) do
      SupplierImports::SyncRemoteStatusService.new(account: @account_b, supplier_import: @import_a).call
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      SupplierImports::StartRemoteValidationService.new(account: @account_b, supplier_import: @import_a).call
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      SupplierImports::AnonymizeEvidenceService.new(account: @account_b, supplier_import: @import_a).call
    end

    assert_equal "Sim", @import_a.reload.response_payload.dig("records", 0, "call_attempts", 0, "customer_transcript")
  end

  test "commercial services refuse an opportunity from another account" do
    assert_raises(ActiveRecord::RecordNotFound) do
      CommercialOpportunities::StartRemoteValidationService.new(account: @account_b, commercial_opportunity: @opportunity_a).call
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      CommercialOpportunities::SyncRemoteStatusService.new(account: @account_b, commercial_opportunity: @opportunity_a).call
    end
  end

  test "a search from another account cannot become a lot" do
    result = SupplierDiscoverySearches::CreateSupplierImportService.new(account: @account_b, user: @b1, search: @search_a).call

    assert_not result.success?
    assert_equal 0, @account_b.supplier_imports.count
  end

  test "audit entries and privacy refusals only read the given account" do
    assert_equal [], SupplierImports::AuditEntriesService.new(account: @account_b).call
    assert_equal 1, SupplierImports::AuditEntriesService.new(account: @account_a).call.size

    assert_empty SupplierImports::PrivacyRefusalRegistry.blocked_phone_numbers_for(@account_b)
    assert_includes SupplierImports::PrivacyRefusalRegistry.blocked_phone_numbers_for(@account_a), "+5511911111111"
  end

  test "records linked to a lot cannot be moved to another account" do
    opportunity = CommercialOpportunity.new(
      account: @account_b,
      supplier_import: @import_a,
      source_external_id: "b-invasao",
      supplier_name: "Invasão",
      callback_phone: "+5511900000000"
    )
    review = AuditReview.new(
      account: @account_b,
      reviewed_by: @b1,
      supplier_import: @import_a,
      reviewed_result: "wrong_company",
      reviewed_at: Time.current
    )

    assert_not opportunity.valid?
    assert_not review.valid?
    assert opportunity.errors[:supplier_import].present?
  end

  test "records linked to a lot inherit its account" do
    review = @import_a.audit_reviews.create!(reviewed_by: @a1, reviewed_result: "wrong_company", reviewed_at: Time.current)

    assert_equal @account_a, review.account
  end

  test "the LGPD trail refuses an event pointing to another account lot" do
    assert_no_difference -> { PrivacyAuditEvent.count } do
      PrivacyAudit::Logger.log!(account: @account_b, user: @b1, action: "supplier_import_result_exported", supplier_import: @import_a)
    end
  end

  test "background sync uses the token of the lot account" do
    used_tokens = []
    fake_show = Object.new
    fake_show.define_singleton_method(:call) do |api_token:, batch_id:|
      used_tokens << api_token
      { "batch_id" => batch_id, "batch_status" => "processing", "records" => [] }
    end

    service_class = ValidationApi::SupplierValidations::ShowBatchService
    service_class.define_singleton_method(:new) { |*| fake_show }
    begin
      SupplierImports::SyncAllRemoteStatusesService.new.call
    ensure
      service_class.singleton_class.remove_method(:new)
    end

    assert_equal [ "tkn_empresa_a" ], used_tokens
  end
end
