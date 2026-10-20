require "test_helper"

module SupplierImports
  class SyncAllRemoteStatusesServiceTest < ActiveSupport::TestCase
    setup do
      @failing = processing_import!(email: "sync-all-falha@example.com", token: "tkn_falha", remote_batch_id: "lote-com-falha")
      @healthy = processing_import!(email: "sync-all-ok@example.com", token: "tkn_ok", remote_batch_id: "lote-saudavel")
    end

    test "an unexpected failure in one lot does not stop the sync of the other accounts" do
      with_remote_show(
        "lote-com-falha" => -> { raise NoMethodError, "payload inesperado" },
        "lote-saudavel" => -> { completed_response("lote-saudavel") }
      ) do
        assert_nothing_raised { SyncAllRemoteStatusesService.new.call }
      end

      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, @healthy.reload.status
      assert_equal SupplierImport::LOCAL_STATUS_PROCESSING, @failing.reload.status
    end

    test "a validation API error is still recorded on the lot" do
      with_remote_show(
        "lote-com-falha" => -> { raise ValidationApi::Error, "API indisponível" },
        "lote-saudavel" => -> { completed_response("lote-saudavel") }
      ) do
        SyncAllRemoteStatusesService.new.call
      end

      assert_equal "API indisponível", @failing.reload.error_message
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, @healthy.reload.status
    end

    test "recent completed batches refresh at most every fifteen minutes and old batches stop polling" do
      @failing.update!(status: SupplierImport::LOCAL_STATUS_COMPLETED, finished_at: 2.days.ago, last_synced_at: 1.day.ago)
      @healthy.update!(status: SupplierImport::LOCAL_STATUS_COMPLETED, finished_at: 1.hour.ago, last_synced_at: 20.minutes.ago)
      calls = 0
      with_remote_show("lote-saudavel" => -> { calls += 1; completed_response("lote-saudavel") }) do
        2.times { SyncAllRemoteStatusesService.new.call }
      end
      assert_equal 1, calls
      assert @failing.reload.last_synced_at < 23.hours.ago
    end

    private

    def processing_import!(email:, token:, remote_batch_id:)
      user = create_member!(name: "Sync #{token}", email: email, validation_api_token: token)
      SupplierImport.create!(
        account: account_of(user),
        created_by: user,
        status: SupplierImport::LOCAL_STATUS_PROCESSING,
        workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        remote_batch_id: remote_batch_id,
        validation_started_at: 5.minutes.ago
      )
    end

    def completed_response(batch_id)
      {
        "batch_id" => batch_id,
        "batch_status" => "completed",
        "result_ready" => true,
        "total_records" => 1,
        "summary" => { "validated_records" => 1, "confirmed_by_call" => 1 },
        "records" => [ { "external_id" => "1", "final_status" => "validated" } ]
      }
    end

    def with_remote_show(responses)
      fake_show = Object.new
      fake_show.define_singleton_method(:call) { |api_token:, batch_id:| responses.fetch(batch_id).call }
      service_class = ValidationApi::Validations::ShowBatchService
      service_class.define_singleton_method(:new) { |*| fake_show }
      yield
    ensure
      service_class.singleton_class.remove_method(:new)
    end
  end
end
