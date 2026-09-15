require "test_helper"

class CommercialOpportunities::SyncRemoteStatusServiceTest < ActiveSupport::TestCase
  test "does not regress a completed collection with an older processing snapshot" do
    opportunity, user = build_opportunity(
      status: CommercialOpportunity::STATUS_COMPLETED,
      remote_batch_status: "completed",
      result_ready: true,
      finished_at: Time.zone.parse("2026-08-15 12:00:00 UTC"),
      response_payload: {
        "batch_status" => "completed",
        "result_ready" => true,
        "records" => [ { "commercial_validation" => { "outcome" => "collected" } } ]
      },
      outcome: "collected",
      product_specification: "Produto final"
    )
    original_payload = opportunity.response_payload.deep_dup
    fake_service = fake_remote_service(
      "batch_status" => "processing",
      "result_ready" => false,
      "records" => []
    )
    service = CommercialOpportunities::SyncRemoteStatusService.new(
      user: user,
      commercial_opportunity: opportunity
    )
    service.define_singleton_method(:show_remote_batch_service) { fake_service }

    service.call

    opportunity.reload
    assert_equal CommercialOpportunity::STATUS_COMPLETED, opportunity.status
    assert_equal "completed", opportunity.remote_batch_status
    assert opportunity.result_ready
    assert_equal original_payload, opportunity.response_payload
    assert_equal "Produto final", opportunity.product_specification
    assert_equal "collected", opportunity.outcome
    assert_equal Time.zone.parse("2026-08-15 12:00:00 UTC"), opportunity.finished_at
  end

  test "keeps a cancelled collection terminal when an older active snapshot arrives" do
    opportunity, user = build_opportunity(
      status: CommercialOpportunity::STATUS_PROCESSING,
      remote_batch_status: "processing"
    )
    responses = [
      { "batch_status" => "cancelled", "result_ready" => false, "records" => [] },
      { "batch_status" => "processing", "result_ready" => false, "records" => [] }
    ]
    fake_service = Object.new
    fake_service.define_singleton_method(:call) { |**| responses.shift }
    service = CommercialOpportunities::SyncRemoteStatusService.new(
      user: user,
      commercial_opportunity: opportunity
    )
    service.define_singleton_method(:show_remote_batch_service) { fake_service }

    service.call
    service.call

    opportunity.reload
    assert_equal CommercialOpportunity::STATUS_ERROR, opportunity.status
    assert_equal "cancelled", opportunity.remote_batch_status
    assert_equal "A coleta comercial foi cancelada.", opportunity.error_message
  end

  test "recovers a local transport error when the remote batch is still active" do
    opportunity, user = build_opportunity(
      status: CommercialOpportunity::STATUS_ERROR,
      remote_batch_status: nil,
      error_message: "Tempo esgotado"
    )
    fake_service = fake_remote_service(
      "batch_status" => "processing",
      "result_ready" => false,
      "records" => []
    )
    service = CommercialOpportunities::SyncRemoteStatusService.new(
      user: user,
      commercial_opportunity: opportunity
    )
    service.define_singleton_method(:show_remote_batch_service) { fake_service }

    service.call

    opportunity.reload
    assert_equal CommercialOpportunity::STATUS_PROCESSING, opportunity.status
    assert_equal "processing", opportunity.remote_batch_status
    assert_nil opportunity.error_message
  end

  test "ignores a response from a batch replaced while the request was in flight" do
    opportunity, user = build_opportunity(
      status: CommercialOpportunity::STATUS_PROCESSING,
      remote_batch_status: "processing",
      response_payload: { "batch_id" => "original", "batch_status" => "processing" }
    )
    replacement_batch_id = "commercial-replacement-#{SecureRandom.hex(4)}"
    fake_service = Object.new
    fake_service.define_singleton_method(:call) do |**|
      opportunity.update!(
        remote_batch_id: replacement_batch_id,
        remote_batch_status: "accepted",
        response_payload: { "batch_id" => replacement_batch_id, "batch_status" => "accepted" }
      )
      { "batch_status" => "completed", "result_ready" => true, "records" => [] }
    end
    service = CommercialOpportunities::SyncRemoteStatusService.new(
      user: user,
      commercial_opportunity: opportunity
    )
    service.define_singleton_method(:show_remote_batch_service) { fake_service }

    service.call

    opportunity.reload
    assert_equal replacement_batch_id, opportunity.remote_batch_id
    assert_equal "accepted", opportunity.remote_batch_status
    assert_equal CommercialOpportunity::STATUS_PROCESSING, opportunity.status
    assert_equal replacement_batch_id, opportunity.response_payload["batch_id"]
  end

  private

  def build_opportunity(**attributes)
    user = users(:one)
    user.update!(validation_api_token: "lp_test_token")
    supplier_import = user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD
    )
    opportunity = user.commercial_opportunities.create!({
      supplier_import: supplier_import,
      source_external_id: "supplier-#{SecureRandom.hex(4)}",
      supplier_name: "Fornecedor Exemplo",
      callback_phone: "+5511987654321",
      remote_batch_id: "commercial-#{SecureRandom.hex(4)}",
      started_at: 5.minutes.ago
    }.merge(attributes))

    [ opportunity, user ]
  end

  def fake_remote_service(response)
    Struct.new(:response) do
      def call(api_token:, batch_id:)
        raise "token ausente" if api_token.blank?
        raise "batch ausente" if batch_id.blank?

        response
      end
    end.new(response)
  end
end
