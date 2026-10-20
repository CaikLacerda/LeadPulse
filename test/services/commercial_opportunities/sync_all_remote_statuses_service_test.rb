require "test_helper"

class CommercialOpportunities::SyncAllRemoteStatusesServiceTest < ActiveSupport::TestCase
  test "an unexpected failure in one collection does not stop the others" do
    failing = processing_opportunity!(email: "sync-all-comercial-falha@example.com", token: "tkn_comercial_falha", remote_batch_id: "coleta-com-falha")
    healthy = processing_opportunity!(email: "sync-all-comercial-ok@example.com", token: "tkn_comercial_ok", remote_batch_id: "coleta-saudavel")
    responses = {
      "coleta-com-falha" => -> { raise TypeError, "payload inesperado" },
      "coleta-saudavel" => -> { { "batch_id" => "coleta-saudavel", "batch_status" => "completed", "result_ready" => true, "records" => [] } }
    }
    fake_show = Object.new
    fake_show.define_singleton_method(:call) { |api_token:, batch_id:| responses.fetch(batch_id).call }
    service_class = ValidationApi::CommercialValidations::ShowBatchService
    service_class.define_singleton_method(:new) { |*| fake_show }

    begin
      assert_nothing_raised { CommercialOpportunities::SyncAllRemoteStatusesService.new.call }
    ensure
      service_class.singleton_class.remove_method(:new)
    end

    assert_equal CommercialOpportunity::STATUS_COMPLETED, healthy.reload.status
    assert_equal CommercialOpportunity::STATUS_PROCESSING, failing.reload.status
  end

  private

  def processing_opportunity!(email:, token:, remote_batch_id:)
    user = create_member!(name: "Comercial #{token}", email: email, validation_api_token: token)
    account = account_of(user)
    supplier_import = SupplierImport.create!(
      account: account,
      created_by: user,
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD
    )
    supplier_import.commercial_opportunities.create!(
      account: account,
      source_external_id: "1",
      supplier_name: "Fornecedor #{token}",
      callback_phone: "+5511999990000",
      status: CommercialOpportunity::STATUS_PROCESSING,
      remote_batch_id: remote_batch_id,
      started_at: 5.minutes.ago
    )
  end
end
