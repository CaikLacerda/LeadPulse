require "test_helper"

class CommercialOpportunities::StartRemoteValidationServiceTest < ActiveSupport::TestCase
  test "sends the confirmed callback phone and keeps scheduling manual" do
    user = users(:one)
    user.update!(validation_api_token: "lp_test_token")
    supplier_import = user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD
    )
    opportunity = user.commercial_opportunities.create!(
      supplier_import: supplier_import,
      source_external_id: "supplier-1",
      supplier_name: "Fornecedor Exemplo",
      callback_phone: "+5511987654321",
      callback_preferred_time: "Sexta-feira à tarde"
    )
    captured_payload = nil
    fake_service = Object.new
    fake_service.define_singleton_method(:call) do |api_token:, payload:|
      raise "token inesperado" unless api_token == "lp_test_token"
      captured_payload = payload
      {
        "batch_id" => payload["batch_id"],
        "batch_status" => "processing",
        "result_ready" => false,
        "records" => []
      }
    end
    service_class = ValidationApi::CommercialValidations::CreateBatchService
    original_constructor = service_class.method(:new)
    service_class.define_singleton_method(:new) { fake_service }

    begin
      CommercialOpportunities::StartRemoteValidationService.new(
        user: user,
        commercial_opportunity: opportunity
      ).call
    ensure
      service_class.define_singleton_method(:new, original_constructor)
    end

    opportunity.reload
    record = captured_payload.fetch("records").first
    assert_equal "+5511987654321", record["phone"]
    assert_equal "Sexta-feira à tarde", record["preferred_callback_time"]
    assert_equal "coleta_de_condicoes_comerciais_por_chamada_automatizada", captured_payload.dig("privacy_notice", "purpose")
    assert_equal CommercialOpportunity::STATUS_PROCESSING, opportunity.status
    assert opportunity.started_at.present?
  end

  test "persists and reuses the exact batch after a timeout" do
    user = users(:one)
    user.update!(validation_api_token: "lp_test_token")
    supplier_import = user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD
    )
    opportunity = user.commercial_opportunities.create!(
      supplier_import: supplier_import,
      source_external_id: "supplier-timeout",
      supplier_name: "Fornecedor Timeout",
      callback_phone: "+5511987654321"
    )
    captured_payloads = []
    fake_service = Object.new
    fake_service.define_singleton_method(:call) do |api_token:, payload:|
      raise "token inesperado" unless api_token == "lp_test_token"

      captured_payloads << payload.deep_dup
      if captured_payloads.one?
        raise ValidationApi::Error.new("Tempo esgotado ao chamar a API de validação.", status_code: 408)
      end

      {
        "batch_id" => payload["batch_id"],
        "batch_status" => "accepted",
        "result_ready" => false,
        "records" => []
      }
    end
    service = CommercialOpportunities::StartRemoteValidationService.new(
      user: user,
      commercial_opportunity: opportunity
    )
    service.define_singleton_method(:create_remote_batch_service) { fake_service }

    assert_raises(ValidationApi::Error) { service.call }

    opportunity.reload
    persisted_batch_id = opportunity.remote_batch_id
    persisted_payload = opportunity.request_payload.deep_dup
    assert persisted_batch_id.present?
    assert_equal persisted_batch_id, persisted_payload["batch_id"]
    assert_equal CommercialOpportunity::STATUS_ERROR, opportunity.status

    service.call

    opportunity.reload
    assert_equal 2, captured_payloads.size
    assert_equal captured_payloads.first, captured_payloads.second
    assert_equal persisted_payload, opportunity.request_payload
    assert_equal persisted_batch_id, opportunity.remote_batch_id
    assert_equal CommercialOpportunity::STATUS_PROCESSING, opportunity.status
  end


  test "does not post again while the persisted batch is already active" do
    user = users(:one)
    user.update!(validation_api_token: "lp_test_token")
    supplier_import = user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD
    )
    opportunity = user.commercial_opportunities.create!(
      supplier_import: supplier_import,
      source_external_id: "supplier-active",
      supplier_name: "Fornecedor Ativo",
      callback_phone: "+5511987654321"
    )
    calls = 0
    fake_service = Object.new
    fake_service.define_singleton_method(:call) do |api_token:, payload:|
      calls += 1
      {
        "batch_id" => payload["batch_id"],
        "batch_status" => "accepted",
        "result_ready" => false,
        "records" => []
      }
    end
    service = CommercialOpportunities::StartRemoteValidationService.new(
      user: user,
      commercial_opportunity: opportunity
    )
    service.define_singleton_method(:create_remote_batch_service) { fake_service }

    first_response = service.call
    second_response = service.call

    assert_equal 1, calls
    assert_equal first_response, second_response
    assert_equal first_response["batch_id"], opportunity.reload.remote_batch_id
    assert_equal CommercialOpportunity::STATUS_PROCESSING, opportunity.status
  end
end
