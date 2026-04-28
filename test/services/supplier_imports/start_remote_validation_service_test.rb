require "test_helper"

module SupplierImports
  class StartRemoteValidationServiceTest < ActiveSupport::TestCase
    test "restarts an errored import" do
      user = User.create!(
        name: "LeadPulse Operacao",
        email: "restart-import@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        validation_api_token: "lp_test_token"
      )

      supplier_import = SupplierImport.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_ERROR,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        remote_batch_id: "old-batch-id",
        remote_batch_status: "completed",
        validation_started_at: 1.hour.ago,
        error_message: "Ligação concluída sem classificação automática definitiva.",
        request_payload: {
          callback_phone: "+55 11 98888-7777",
          records: [
            {
              external_id: "1.0",
              phone: "11 99999-0000",
              cnpj: "",
              client_name: "Fornecedor Exemplo"
            }
          ]
        }
      )

      fake_response = {
        "batch_id" => "new-batch-id",
        "batch_status" => "accepted",
        "result_ready" => false,
        "finished_at" => nil
      }

      fake_remote_service = Struct.new(:response) do
        def call(api_token:, payload:)
          raise "expected api token" if api_token.blank?
          raise "expected normalized payload" unless payload.dig("records", 0, "external_id") == "1"
          raise "expected refreshed batch id" if payload["batch_id"] == "old-batch-id"

          response
        end
      end.new(fake_response)

      service = StartRemoteValidationService.new(user: user, supplier_import: supplier_import)

      service.stub(:create_remote_batch_service, fake_remote_service) do
        service.call
      end

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_PROCESSING, supplier_import.status
      assert_equal "new-batch-id", supplier_import.remote_batch_id
      assert_equal "accepted", supplier_import.remote_batch_status
      assert_nil supplier_import.error_message
      assert supplier_import.validation_started_at.present?
      assert supplier_import.request_payload["batch_id"].present?
      assert_not_equal "old-batch-id", supplier_import.request_payload["batch_id"]
    end
  end
end
