require "test_helper"

module SupplierImports
  # Contrato com a API de validação: os JSONs em test/fixtures/files/validation_api foram
  # gerados pela própria API (scripts/export_contract_fixtures.py em api_confaith_ai).
  class RemoteEvidenceMergerTest < ActiveSupport::TestCase
    setup do
      user = create_member!(name: "Evidencias", email: "evidencias@example.com", validation_api_token: "tkn_evidencias")
      @account = account_of(user)
      @import = SupplierImport.create!(
        account: @account,
        created_by: user,
        status: SupplierImport::LOCAL_STATUS_PROCESSING,
        workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        remote_batch_id: "lp_batch_contract",
        validation_started_at: 10.minutes.ago,
        request_payload: { "privacy_notice" => { "legal_basis" => "legitimate_interest", "recording_allowed" => true } }
      )
      @result = api_fixture("validation_batch_result")
      @evidence = api_fixture("validation_batch_evidence")
      @evidence_calls = []
    end

    test "the split API result has no evidence and the sync brings it back from the evidence endpoint" do
      assert_not @result["records"].first.key?("call_attempts")

      sync!

      record = @import.reload.response_payload["records"].first
      attempt = record["call_attempts"].first
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, @import.status
      assert_equal 42, attempt["duration_seconds"]
      assert attempt["recording_url"].present?
      assert_equal %w[assistant user], attempt["conversation_turns"].map { |turn| turn["role"] }
      assert_equal [ { api_token: "tkn_evidencias", batch_id: "lp_batch_contract", limit: 200, offset: 0 } ], @evidence_calls
    end

    test "the evidence expiry from the API feeds the local retention and keeps the privacy notice" do
      sync!

      @import.reload
      assert_equal ValidationApi::Timestamp.parse(@evidence["evidence_expires_at"]), @import.evidence_expires_at
      assert_equal "legitimate_interest", @import.privacy_notice["legal_basis"]
      assert_not @import.evidence_retention_expired?
    end

    test "audit and analytics read the merged attempts" do
      sync!

      entries = AuditEntriesService.call(account: @account)
      assert_equal 1, entries.size
      assert entries.first.recording_url.present?
      assert_equal 2, entries.first.conversation_turns.size
    end

    test "an unchanged result does not fetch the evidence again" do
      sync!
      sync!

      assert_equal 1, @evidence_calls.size
      assert @import.reload.response_payload["records"].first["call_attempts"].present?
    end

    test "a failure on the evidence endpoint keeps the stored evidence and still applies the status" do
      sync!
      @result["records"].first["attempts_count"] = 2
      @evidence_failure = ValidationApi::Error.new("Falha de conexão com a API de validação.")

      sync!

      assert_equal 2, @evidence_calls.size
      record = @import.reload.response_payload["records"].first
      assert_equal 2, record["attempts_count"]
      assert_equal 1, record["call_attempts"].size
    end

    test "large lots are read page by page" do
      @evidence_pages = [ @evidence.merge("has_more" => true, "records" => []), @evidence ]

      sync!

      assert_equal [ 0, 200 ], @evidence_calls.map { |call| call[:offset] }
      assert @import.reload.response_payload["records"].first["call_attempts"].present?
    end

    test "anonymization keeps the attempts and removes transcripts and recordings" do
      sync!
      anonymize_response = @result
      service_class = ValidationApi::Validations::AnonymizeEvidenceService
      service_class.define_singleton_method(:new) do |*|
        Object.new.tap { |fake| fake.define_singleton_method(:call) { |api_token:, batch_id:| anonymize_response } }
      end

      begin
        AnonymizeEvidenceService.new(account: @account, supplier_import: @import.reload).call
      ensure
        service_class.singleton_class.remove_method(:new)
      end

      attempt = @import.reload.response_payload["records"].first["call_attempts"].first
      assert_equal 42, attempt["duration_seconds"]
      assert_nil attempt["recording_url"]
      assert_empty attempt["conversation_turns"]
      assert @import.evidence_anonymized?
    end

    test "pagination continues beyond two thousand records" do
      @evidence_pages = 11.times.map do |page|
        @evidence.deep_dup.merge("has_more" => page < 10,
          "records" => page == 10 ? @evidence["records"] : [])
      end
      sync!
      assert_equal 11, @evidence_calls.size
      assert_equal 2000, @evidence_calls.last[:offset]
      assert_equal 1, @import.reload.response_payload["records"].first["call_attempts"].size
    end

    test "late recording is refreshed with a bounded interval and attempts are deduplicated" do
      @evidence["records"].first["call_attempts"].first["recording_url"] = nil
      sync!
      @evidence["records"].first["call_attempts"].first["recording_url"] = "https://recordings.example.test/late"
      travel 16.minutes do
        sync!
        sync!
      end
      attempts = @import.reload.response_payload["records"].first["call_attempts"]
      assert_equal 2, @evidence_calls.size
      assert_equal 1, attempts.size
      assert_equal "https://recordings.example.test/late", attempts.first["recording_url"]
    end

    test "partial evidence preserves attempts already stored" do
      sync!
      @evidence["records"].first["call_attempts"] = [ @evidence["records"].first["call_attempts"].first.merge("attempt_number" => 2) ]
      @result["records"].first["attempts_count"] = 2
      sync!
      assert_equal [ 1, 2 ], @import.reload.response_payload["records"].first["call_attempts"].map { |attempt| attempt["attempt_number"] }
    end

    test "sync cannot resurrect anonymized evidence" do
      sync!
      @import.update!(import_metadata: @import.import_metadata.merge("evidence_anonymized_at" => Time.current.iso8601))
      travel 16.minutes do
        sync!
      end
      assert_equal 1, @evidence_calls.size
      attempt = @import.reload.response_payload["records"].first["call_attempts"].first
      assert_nil attempt["recording_url"]
      assert_empty attempt["conversation_turns"]
      assert_equal 42, attempt["duration_seconds"]
    end

    test "foreign batch evidence is rejected without deleting previous attempts" do
      sync!
      @result["records"].first["attempts_count"] = 2
      @evidence["batch_id"] = "foreign_batch"
      sync!
      assert_equal 1, @import.reload.response_payload["records"].first["call_attempts"].size
    end

    test "an endless evidence endpoint does not commit a truncated snapshot" do
      @evidence["has_more"] = true
      sync!
      assert_equal RemoteEvidenceMerger::MAX_PAGES, @evidence_calls.size
      assert_nil @import.reload.response_payload[RemoteEvidenceMerger::SYNCED_AT_KEY]
    end

    test "a mismatched result batch cannot overwrite the local batch" do
      sync!
      original = @import.reload.response_payload.deep_dup
      @result["batch_id"] = "foreign_batch"
      assert_raises(ValidationApi::Error) { sync! }
      assert_equal original, @import.reload.response_payload
    end

    test "merger refuses a different account even with matching external ids" do
      other = Account.create!(name: "Other tenant")
      assert_raises(ActiveRecord::RecordNotFound) do
        RemoteEvidenceMerger.new(account: other, supplier_import: @import).call(@result, batch_id: @import.remote_batch_id)
      end
    end

    test "anonymization reloads attempts added while the remote request was in flight" do
      sync!
      stale_import = SupplierImport.find(@import.id)
      newer = @import.response_payload.deep_dup
      newer["records"].first["call_attempts"] << newer["records"].first["call_attempts"].first.merge("attempt_number" => 2)
      @import.update!(response_payload: newer)
      response = @result
      service = AnonymizeEvidenceService.new(account: @account, supplier_import: stale_import)
      service.define_singleton_method(:anonymize_remote_evidence) { response }
      service.call
      attempts = @import.reload.response_payload["records"].first["call_attempts"]
      assert_equal [ 1, 2 ], attempts.map { |attempt| attempt["attempt_number"] }
      assert attempts.all? { |attempt| attempt["recording_url"].nil? }
    end

    test "anonymization cannot apply an old batch response to a replacement batch" do
      sync!
      response = @result.deep_dup
      replacement = { "batch_id" => "replacement_batch", "records" => [] }
      current_import = @import
      service = AnonymizeEvidenceService.new(account: @account, supplier_import: SupplierImport.find(@import.id))
      service.define_singleton_method(:anonymize_remote_evidence) do
        current_import.update!(remote_batch_id: "replacement_batch", response_payload: replacement)
        response
      end

      assert_raises(ValidationApi::Error) { service.call }
      assert_equal replacement, @import.reload.response_payload
      assert_not @import.import_metadata.key?("evidence_anonymized_at")
    end

    private

    def api_fixture(name)
      directory = ENV["VALIDATION_API_CONTRACT_FIXTURES_DIR"]
      path = directory.present? ? Pathname.new(directory).join("#{name}.json") : file_fixture("validation_api/#{name}.json")
      JSON.parse(path.read)
    end

    def sync!
      result = @result.deep_dup
      show = Object.new
      show.define_singleton_method(:call) { |api_token:, batch_id:| result }
      test_case = self
      evidence = Object.new
      evidence.define_singleton_method(:call) { |**args| test_case.send(:evidence_page, **args) }
      account = @account
      import = @import.reload

      service = SyncRemoteStatusService.new(account: account, supplier_import: import)
      service.define_singleton_method(:show_remote_batch_service) { show }
      service.define_singleton_method(:remote_evidence_merger) do
        RemoteEvidenceMerger.new(account: account, supplier_import: import, evidence_service: evidence)
      end
      service.call
    end

    def evidence_page(**args)
      @evidence_calls << args
      raise @evidence_failure if @evidence_failure
      return @evidence_pages.shift if @evidence_pages

      @evidence
    end
  end
end
