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
        "batch_status" => "accepted",
        "result_ready" => false,
        "finished_at" => nil
      }

      fake_remote_service = Struct.new(:response) do
        def call(api_token:, payload:)
          raise "expected api token" if api_token.blank?
          raise "expected normalized payload" unless payload.dig("records", 0, "external_id") == "1"
          raise "expected a fresh batch id" unless payload["batch_id"].start_with?("lp_batch_")
          raise "expected a fresh batch id" if payload["batch_id"] == "old-batch-id"
          raise "expected Brazilian callback" unless payload["callback_phone"] == "+5511988887777"

          response.merge("batch_id" => payload["batch_id"])
        end
      end.new(fake_response)

      service = StartRemoteValidationService.new(user: user, supplier_import: supplier_import)
      service.define_singleton_method(:create_remote_batch_service) { fake_remote_service }

      service.call

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_PROCESSING, supplier_import.status
      assert_match(/\Alp_batch_\d{14}_[0-9a-f]{6}\z/, supplier_import.remote_batch_id)
      assert_equal "accepted", supplier_import.remote_batch_status
      assert_nil supplier_import.error_message
      assert supplier_import.validation_started_at.present?
      assert supplier_import.request_payload["batch_id"].present?
      assert_equal supplier_import.remote_batch_id, supplier_import.request_payload["batch_id"]
    end

    test "repairs Brazilian prefix previously added to configured international Twilio number" do
      user = User.create!(
        name: "LeadPulse Operacao",
        email: "international-callback@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        validation_api_token: "lp_test_token",
        validation_twilio_phone_numbers: [
          { "phone_number" => "+13527176703", "is_active" => true }
        ]
      )

      supplier_import = SupplierImport.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_PENDING,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        remote_batch_id: "international-callback-batch",
        request_payload: {
          batch_id: "international-callback-batch",
          callback_phone: "+5513527176703",
          records: [
            {
              external_id: "1",
              phone: "11 99999-0000",
              supplier_name: "Fornecedor Exemplo"
            }
          ]
        }
      )

      fake_remote_service = Object.new
      fake_remote_service.define_singleton_method(:call) do |api_token:, payload:|
        raise "expected api token" if api_token.blank?
        raise "expected repaired callback" unless payload["callback_phone"] == "+13527176703"

        {
          "batch_id" => payload["batch_id"],
          "batch_status" => "accepted",
          "result_ready" => false,
          "finished_at" => nil
        }
      end

      service = StartRemoteValidationService.new(user: user, supplier_import: supplier_import)
      service.define_singleton_method(:create_remote_batch_service) { fake_remote_service }

      service.call

      assert_equal "+13527176703", supplier_import.reload.request_payload["callback_phone"]
    end

    test "keeps an immediately inconclusive supplier batch completed and exportable" do
      user = User.create!(
        name: "LeadPulse Operacao",
        email: "start-inconclusive@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        validation_api_token: "lp_test_token"
      )
      supplier_import = SupplierImport.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_PENDING,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        request_payload: {
          batch_id: "immediate-inconclusive",
          callback_phone: "+5511999999999",
          records: [ { external_id: "1", phone: "11988887777", supplier_name: "Fornecedor" } ]
        }
      )
      fake_remote_service = Struct.new(:response) do
        def call(api_token:, payload:)
          raise "expected api token" if api_token.blank?
          raise "expected payload" if payload.blank?

          response
        end
      end.new(
        {
          "batch_id" => "immediate-inconclusive",
          "batch_status" => "completed",
          "result_ready" => true,
          "total_records" => 1,
          "summary" => { "failed_records" => 1 },
          "records" => [
            {
              "call_result" => "inconclusive",
              "final_status" => "validation_failed",
              "supplier_validation" => { "outcome" => "inconclusive" }
            }
          ]
        }
      )
      service = StartRemoteValidationService.new(user: user, supplier_import: supplier_import)
      service.define_singleton_method(:create_remote_batch_service) { fake_remote_service }

      service.call

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, supplier_import.status
      assert supplier_import.result_ready
      assert supplier_import.ready_to_export?
      assert_nil supplier_import.error_message
    end
  end
end
