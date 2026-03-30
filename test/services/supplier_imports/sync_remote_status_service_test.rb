require "test_helper"

module SupplierImports
  class SyncRemoteStatusServiceTest < ActiveSupport::TestCase
    test "marks supplier batch with negative business outcome as completed" do
      user = User.create!(
        name: "LeadPulse Operacao",
        email: "sync-supplier-negative@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        validation_api_token: "lp_test_token"
      )

      supplier_import = SupplierImport.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_PROCESSING,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        remote_batch_id: "remote-supplier-batch"
      )

      fake_response = {
        "batch_status" => "completed",
        "result_ready" => true,
        "finished_at" => Time.current.iso8601,
        "total_records" => 1,
        "summary" => {
          "validated_records" => 0,
          "failed_records" => 1,
          "invalid_phone" => 0,
          "confirmed_by_call" => 0,
          "confirmed_by_whatsapp" => 0,
          "confirmed_by_email" => 0
        },
        "records" => [
          {
            "final_status" => "validation_failed",
            "observation" => "Fornecedor recusado na ligacao de qualificacao.",
            "supplier_validation" => {
              "outcome" => "does_not_supply_segment"
            }
          }
        ]
      }

      fake_remote_service = Struct.new(:response) do
        def call(api_token:, batch_id:)
          raise "expected api token" if api_token.blank?
          raise "unexpected batch id" if batch_id != "remote-supplier-batch"

          response
        end
      end.new(fake_response)

      service = SyncRemoteStatusService.new(user: user, supplier_import: supplier_import)

      service.stub(:show_remote_batch_service, fake_remote_service) do
        service.call
      end

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, supplier_import.status
      assert_nil supplier_import.error_message
      assert_equal "completed", supplier_import.remote_batch_status
      assert supplier_import.result_ready
    end
  end
end
