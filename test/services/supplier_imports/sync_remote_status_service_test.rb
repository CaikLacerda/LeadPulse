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
      service.define_singleton_method(:show_remote_batch_service) { fake_remote_service }

      service.call

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, supplier_import.status
      assert_nil supplier_import.error_message
      assert_equal "completed", supplier_import.remote_batch_status
      assert supplier_import.result_ready
    end

    test "marks inconclusive supplier batch as completed and exportable" do
      user = User.create!(
        name: "LeadPulse Operacao",
        email: "sync-supplier-inconclusive@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        validation_api_token: "lp_test_token"
      )

      supplier_import = SupplierImport.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_PROCESSING,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 4,
        valid_rows: 1,
        invalid_rows: 3,
        remote_batch_id: "remote-inconclusive-batch"
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
            "call_result" => "inconclusive",
            "observation" => "Ligacao concluida sem classificacao automatica definitiva.",
            "supplier_validation" => {
              "outcome" => "inconclusive"
            }
          }
        ]
      }

      fake_remote_service = Struct.new(:response) do
        def call(api_token:, batch_id:)
          raise "expected api token" if api_token.blank?
          raise "unexpected batch id" if batch_id != "remote-inconclusive-batch"

          response
        end
      end.new(fake_response)

      service = SyncRemoteStatusService.new(user: user, supplier_import: supplier_import)
      service.define_singleton_method(:show_remote_batch_service) { fake_remote_service }

      service.call

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, supplier_import.status
      assert_nil supplier_import.error_message
      assert supplier_import.result_ready
      assert supplier_import.ready_to_export?
    end

    test "does not regress a completed batch with an older processing snapshot" do
      user = User.create!(
        name: "LeadPulse Operacao",
        email: "sync-supplier-monotonic@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        validation_api_token: "lp_test_token"
      )
      finished_at = Time.zone.parse("2026-08-15 12:00:00 UTC")
      completed_payload = {
        "batch_status" => "completed",
        "result_ready" => true,
        "records" => [ { "external_id" => "1", "final_status" => "qualified_supplier" } ]
      }
      supplier_import = SupplierImport.create!(
        user: user,
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        remote_batch_id: "remote-completed-batch",
        remote_batch_status: "completed",
        response_payload: completed_payload,
        result_ready: true,
        finished_at: finished_at
      )
      fake_remote_service = Struct.new(:response) do
        def call(**)
          response
        end
      end.new({
        "batch_status" => "processing",
        "result_ready" => false,
        "records" => []
      })
      service = SyncRemoteStatusService.new(user: user, supplier_import: supplier_import)
      service.define_singleton_method(:show_remote_batch_service) { fake_remote_service }

      service.call

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, supplier_import.status
      assert_equal "completed", supplier_import.remote_batch_status
      assert supplier_import.result_ready
      assert_equal completed_payload, supplier_import.response_payload
      assert_equal finished_at, supplier_import.finished_at
    end

    test "keeps a cancelled batch terminal when an older queued snapshot arrives" do
      user = User.create!(
        name: "LeadPulse Operacao",
        email: "sync-supplier-cancelled@example.com",
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
        remote_batch_id: "remote-cancelled-batch",
        remote_batch_status: "processing"
      )
      responses = [
        { "batch_status" => "cancelled", "result_ready" => false, "records" => [] },
        { "batch_status" => "queued", "result_ready" => false, "records" => [] }
      ]
      fake_remote_service = Object.new
      fake_remote_service.define_singleton_method(:call) { |**| responses.shift }
      service = SyncRemoteStatusService.new(user: user, supplier_import: supplier_import)
      service.define_singleton_method(:show_remote_batch_service) { fake_remote_service }

      service.call
      service.call

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_ERROR, supplier_import.status
      assert_equal "cancelled", supplier_import.remote_batch_status
      assert_equal "O lote foi cancelado antes da conclusão.", supplier_import.error_message
    end


    test "recovers a local transport error when the remote batch is processing" do
      user = users(:one)
      user.update!(validation_api_token: "lp_test_token")
      supplier_import = user.supplier_imports.create!(
        status: SupplierImport::LOCAL_STATUS_ERROR,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        remote_batch_id: "remote-transport-error",
        remote_batch_status: nil,
        error_message: "Tempo esgotado"
      )
      fake_service = Struct.new(:response) do
        def call(**)
          response
        end
      end.new({
        "batch_status" => "processing",
        "result_ready" => false,
        "records" => []
      })
      service = SyncRemoteStatusService.new(user: user, supplier_import: supplier_import)
      service.define_singleton_method(:show_remote_batch_service) { fake_service }

      service.call

      supplier_import.reload
      assert_equal SupplierImport::LOCAL_STATUS_PROCESSING, supplier_import.status
      assert_equal "processing", supplier_import.remote_batch_status
      assert_nil supplier_import.error_message
    end


    test "ignores a response from a batch replaced while the request was in flight" do
      user = users(:one)
      user.update!(validation_api_token: "lp_test_token")
      supplier_import = user.supplier_imports.create!(
        status: SupplierImport::LOCAL_STATUS_PROCESSING,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        remote_batch_id: "remote-original-batch",
        remote_batch_status: "processing",
        response_payload: { "batch_id" => "remote-original-batch", "batch_status" => "processing" }
      )
      fake_service = Object.new
      fake_service.define_singleton_method(:call) do |**|
        supplier_import.update!(
          remote_batch_id: "remote-replacement-batch",
          remote_batch_status: "accepted",
          response_payload: { "batch_id" => "remote-replacement-batch", "batch_status" => "accepted" }
        )
        { "batch_status" => "completed", "result_ready" => true, "records" => [] }
      end
      service = SyncRemoteStatusService.new(user: user, supplier_import: supplier_import)
      service.define_singleton_method(:show_remote_batch_service) { fake_service }

      service.call

      supplier_import.reload
      assert_equal "remote-replacement-batch", supplier_import.remote_batch_id
      assert_equal "accepted", supplier_import.remote_batch_status
      assert_equal SupplierImport::LOCAL_STATUS_PROCESSING, supplier_import.status
      assert_equal "remote-replacement-batch", supplier_import.response_payload["batch_id"]
    end
  end
end
