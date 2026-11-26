require "test_helper"

module SupplierImports
  class StartSyncRacesTest < ActiveSupport::TestCase
    setup do
      user = create_member!(name: "Start races", email: "start-races@example.test", validation_api_token: "tkn_start_races")
      @account = account_of(user)
      @import = SupplierImport.create!(account: @account, created_by: user,
        status: SupplierImport::LOCAL_STATUS_ERROR, workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        source: SupplierImport::SOURCE_UPLOAD, total_rows: 1, valid_rows: 1, invalid_rows: 0,
        remote_batch_id: "old_batch", remote_batch_status: "completed", validation_started_at: 1.hour.ago,
        request_payload: { "batch_id" => "old_batch", "records" => [ { "external_id" => "1", "phone" => "+5511999999999" } ] },
        response_payload: { "records" => [ { "external_id" => "1", "call_attempts" => [ attempt ] } ] })
    end

    test "a replacement batch does not inherit evidence from the previous batch even after a creation timeout" do
      remote = lambda do |api_token:, payload:|
        current = @import.reload
        result = { "batch_id" => payload["batch_id"], "records" => [ { "external_id" => "1", "attempts_count" => 0 } ] }
        merged = RemoteEvidenceMerger.new(account: @account, supplier_import: current).carry_over(result)
        assert_empty Array(merged["records"].first["call_attempts"])
        raise ValidationApi::Error, "timeout"
      end
      assert_raises(ValidationApi::Error) { start_with(remote) }
      assert_equal "https://recordings.example.test/old", @import.reload.response_payload["records"].first["call_attempts"].first["recording_url"]
    end

    test "a delayed creation acknowledgement does not overwrite completed sync or its evidence" do
      remote = lambda do |api_token:, payload:|
        sync_result(payload["batch_id"], status: "completed")
        { "batch_id" => payload["batch_id"], "batch_status" => "processing", "result_ready" => false }
      end
      start_with(remote)
      @import.reload
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, @import.status
      assert_equal "completed", @import.remote_batch_status
      assert @import.result_ready?
      assert_equal 1, @import.response_payload["records"].first["call_attempts"].size
      assert_not @import.import_metadata.key?(StartRemoteValidationService::CLAIM_KEY)
    end

    test "creation response cannot restore evidence anonymized while creation was in flight" do
      remote = lambda do |api_token:, payload:|
        result = sync_result(payload["batch_id"], status: "processing")
        anonymizer = AnonymizeEvidenceService.new(account: @account, supplier_import: SupplierImport.find(@import.id))
        anonymizer.define_singleton_method(:anonymize_remote_evidence) { result }
        anonymizer.call
        result
      end
      start_with(remote)
      @import.reload
      assert @import.evidence_anonymized?
      calls = @import.response_payload["records"].first["call_attempts"]
      assert_equal 1, calls.size
      assert_nil calls.first["recording_url"]
      assert_empty calls.first["conversation_turns"]
      assert_equal 42, calls.first["duration_seconds"]
    end

    private

    def attempt
      { "attempt_number" => 1, "recording_url" => "https://recordings.example.test/old", "duration_seconds" => 42,
        "conversation_turns" => [ { "role" => "user", "transcript" => "Private" } ] }
    end

    def sync_result(batch_id, status:)
      result = { "batch_id" => batch_id, "batch_status" => status, "result_ready" => status == "completed",
        "total_records" => 1, "summary" => { "validated_records" => 1 },
        "records" => [ { "external_id" => "1", "attempts_count" => 1, "call_attempts" => [ attempt ] } ] }
      fake = Object.new
      fake.define_singleton_method(:call) { |**| result }
      sync = SyncRemoteStatusService.new(account: @account, supplier_import: SupplierImport.find(@import.id))
      sync.define_singleton_method(:show_remote_batch_service) { fake }
      sync.call
      result
    end

    def start_with(callback)
      fake = Object.new
      fake.define_singleton_method(:call) { |**args| callback.call(**args) }
      service = StartRemoteValidationService.new(account: @account, supplier_import: @import)
      service.define_singleton_method(:create_remote_batch_service) { fake }
      service.call
    end
  end
end
