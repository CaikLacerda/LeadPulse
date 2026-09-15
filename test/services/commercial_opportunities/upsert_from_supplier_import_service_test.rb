require "test_helper"

class CommercialOpportunities::UpsertFromSupplierImportServiceTest < ActiveSupport::TestCase
  test "creates one pending opportunity for an accepted commercial callback" do
    user = users(:one)
    supplier_import = user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD,
      response_payload: {
        "records" => [
          {
            "external_id" => "supplier-1",
            "client_name" => "Aços Campinas",
            "phone_original" => "+551133333333",
            "supplier_validation" => {
              "segment_name" => "Aço galvanizado",
              "commercial_interest" => true,
              "callback_phone_informed" => "+5511987654321",
              "callback_phone_choice" => "alternate_number",
              "callback_preferred_time" => "Dia 26 de julho às cinco da tarde",
              "callback_preferred_at" => "2026-07-26T20:00:00+00:00"
            }
          },
          {
            "external_id" => "supplier-2",
            "client_name" => "Fornecedor sem interesse",
            "supplier_validation" => {
              "commercial_interest" => false
            }
          }
        ]
      }
    )
    service = CommercialOpportunities::UpsertFromSupplierImportService.new(
      supplier_import: supplier_import
    )

    assert_difference -> { CommercialOpportunity.count }, 1 do
      service.call
    end
    assert_no_difference -> { CommercialOpportunity.count } do
      service.call
    end

    opportunity = supplier_import.commercial_opportunities.first
    assert_equal CommercialOpportunity::STATUS_PENDING, opportunity.status
    assert_equal "Aços Campinas", opportunity.supplier_name
    assert_equal "+5511987654321", opportunity.callback_phone
    assert_equal "alternate_number", opportunity.callback_phone_choice
    assert_equal "Dia 26 de julho às cinco da tarde", opportunity.callback_preferred_time
    assert_equal Time.zone.parse("2026-07-26 20:00:00 UTC"), opportunity.callback_preferred_at
    assert_equal "26/07/2026 às 17:00", opportunity.callback_schedule_label
  end

  test "uses the latest human decision before the automatic commercial interest" do
    user = users(:one)
    supplier_import = user.supplier_imports.create!(
      status: SupplierImport::LOCAL_STATUS_COMPLETED,
      workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
      source: SupplierImport::SOURCE_UPLOAD,
      response_payload: {
        "records" => [
          {
            "external_id" => "supplier-blocked-by-review",
            "client_name" => "Falso positivo",
            "supplier_validation" => {
              "commercial_interest" => true,
              "callback_phone_informed" => "+5511987654321"
            }
          },
          {
            "external_id" => "supplier-approved-by-review",
            "client_name" => "Falso negativo",
            "supplier_validation" => {
              "commercial_interest" => false,
              "callback_phone_informed" => "+5511987654322"
            }
          }
        ]
      }
    )
    supplier_import.audit_reviews.create!(
      user: user,
      record_external_id: "supplier-blocked-by-review",
      original_result: "qualified_supplier",
      reviewed_result: "not_interested",
      reviewed_at: 2.minutes.ago
    )
    supplier_import.audit_reviews.create!(
      user: user,
      record_external_id: "supplier-approved-by-review",
      original_result: "not_interested",
      reviewed_result: "qualified_supplier",
      reviewed_at: 1.minute.ago
    )

    assert_difference -> { CommercialOpportunity.count }, 1 do
      CommercialOpportunities::UpsertFromSupplierImportService.new(
        supplier_import: supplier_import
      ).call
    end

    opportunity = supplier_import.commercial_opportunities.first
    assert_equal "supplier-approved-by-review", opportunity.source_external_id
    assert_equal "+5511987654322", opportunity.callback_phone
  end
end
