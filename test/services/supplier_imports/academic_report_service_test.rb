require "test_helper"

module SupplierImports
  class AcademicReportServiceTest < ActiveSupport::TestCase
    test "builds academic xlsx report" do
      user = User.create!(
        name: "LeadPulse Pesquisa",
        email: "relatorio@example.com",
        password: "Password123!",
        password_confirmation: "Password123!"
      )

      user.supplier_imports.create!(
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        import_metadata: {
          "reference_labels" => [
            { "external_id" => "1", "expected_result" => "confirmed_by_call" }
          ]
        },
        response_payload: {
          "records" => [
            {
              "external_id" => "1",
              "business_status" => "confirmed_by_call",
              "call_attempts" => [
                { "duration_seconds" => 12 }
              ]
            }
          ]
        }
      )

      export = AcademicReportService.new(imports: user.supplier_imports).call

      assert_equal AcademicReportService::CONTENT_TYPE, export[:content_type]
      assert_match(/\Arelatorio-tcc-validacao-/, export[:filename])
      assert_equal "PK", export[:content].byteslice(0, 2)
    end
  end
end
