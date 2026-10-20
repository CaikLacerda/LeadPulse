require "test_helper"

module SupplierImports
  class StartRemoteValidationServiceTest < ActiveSupport::TestCase
    test "restarts an errored import" do
      user = create_member!(
        name: "LeadPulse Operacao",
        email: "restart-import@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        validation_api_token: "lp_test_token"
      )

      supplier_import = SupplierImport.create!(
        account: account_of(user),
        created_by: user,
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

      service = StartRemoteValidationService.new(account: account_of(user), supplier_import: supplier_import)
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
      user = create_member!(
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
        account: account_of(user),
        created_by: user,
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

      service = StartRemoteValidationService.new(account: account_of(user), supplier_import: supplier_import)
      service.define_singleton_method(:create_remote_batch_service) { fake_remote_service }

      service.call

      assert_equal "+13527176703", supplier_import.reload.request_payload["callback_phone"]
    end

    test "keeps an immediately inconclusive supplier batch completed and exportable" do
      user = create_member!(
        name: "LeadPulse Operacao",
        email: "start-inconclusive@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        validation_api_token: "lp_test_token"
      )
      supplier_import = SupplierImport.create!(
        account: account_of(user),
        created_by: user,
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
      service = StartRemoteValidationService.new(account: account_of(user), supplier_import: supplier_import)
      service.define_singleton_method(:create_remote_batch_service) { fake_remote_service }

      service.call

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, supplier_import.status
      assert supplier_import.result_ready
      assert supplier_import.ready_to_export?
      assert_nil supplier_import.error_message
    end
    test "a second start while the first request is in flight does not create another remote batch" do
      supplier_import, account = errored_import_with_confirmed_remote_batch!("double-click")
      sent_batch_ids = []
      second_attempt_error = nil
      remote = Object.new
      remote.define_singleton_method(:call) do |api_token:, payload:|
        sent_batch_ids << payload["batch_id"]
        begin
          StartRemoteValidationService.new(account: account, supplier_import: SupplierImport.find(supplier_import.id)).call
        rescue ValidationApi::Error => error
          second_attempt_error = error
        end
        { "batch_id" => payload["batch_id"], "batch_status" => "processing", "result_ready" => false }
      end

      start_with(remote, supplier_import, account)

      assert_equal 1, sent_batch_ids.size
      assert_match(/em andamento/, second_attempt_error&.message)
      assert_equal SupplierImport::LOCAL_STATUS_PROCESSING, supplier_import.reload.status
      assert_not supplier_import.import_metadata.key?(StartRemoteValidationService::CLAIM_KEY)
    end

    test "a retry after a timeout resends the same batch id instead of creating a new remote batch" do
      supplier_import, account = errored_import_with_confirmed_remote_batch!("timeout-retry")
      sent_batch_ids = []
      remote = Object.new
      remote.define_singleton_method(:call) do |api_token:, payload:|
        sent_batch_ids << payload["batch_id"]
        raise ValidationApi::Error.new("Tempo esgotado ao chamar a API de validação.", status_code: 408) if sent_batch_ids.size == 1

        { "batch_id" => payload["batch_id"], "batch_status" => "processing", "result_ready" => false }
      end

      assert_raises(ValidationApi::Error) { start_with(remote, supplier_import, account) }
      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_ERROR, supplier_import.status
      assert_not supplier_import.import_metadata.key?(StartRemoteValidationService::CLAIM_KEY)

      start_with(remote, supplier_import, account)

      assert_equal 2, sent_batch_ids.size
      assert_equal sent_batch_ids.first, sent_batch_ids.last
      assert_not_equal "old-batch-id", sent_batch_ids.first
      assert_equal sent_batch_ids.first, supplier_import.reload.remote_batch_id
      assert_equal SupplierImport::LOCAL_STATUS_PROCESSING, supplier_import.status
    end

    test "an expired claim from an interrupted request does not block a new start" do
      supplier_import, account = errored_import_with_confirmed_remote_batch!("expired-claim")
      supplier_import.update!(import_metadata: { StartRemoteValidationService::CLAIM_KEY => 10.minutes.ago.iso8601 }) # gitleaks:allow (claim timestamp, not a credential)
      remote = Object.new
      remote.define_singleton_method(:call) do |api_token:, payload:|
        { "batch_id" => payload["batch_id"], "batch_status" => "processing", "result_ready" => false }
      end

      start_with(remote, supplier_import, account)

      assert_equal SupplierImport::LOCAL_STATUS_PROCESSING, supplier_import.reload.status
    end

    private

    def errored_import_with_confirmed_remote_batch!(label)
      user = create_member!(name: "Operacao #{label}", email: "start-#{label}@example.com", validation_api_token: "lp_test_token")
      supplier_import = SupplierImport.create!(
        account: account_of(user),
        created_by: user,
        status: SupplierImport::LOCAL_STATUS_ERROR,
        workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        remote_batch_id: "old-batch-id",
        remote_batch_status: "completed",
        validation_started_at: 1.hour.ago,
        request_payload: {
          batch_id: "old-batch-id",
          records: [ { external_id: "1", phone: "11999990000", cnpj: "11222333000181", client_name: "Empresa" } ]
        }
      )
      [ supplier_import, account_of(user) ]
    end

    def start_with(remote, supplier_import, account)
      service = StartRemoteValidationService.new(account: account, supplier_import: supplier_import)
      service.define_singleton_method(:create_remote_batch_service) { remote }
      service.call
    end
  end
end
