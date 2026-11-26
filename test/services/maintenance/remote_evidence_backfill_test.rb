require "test_helper"

module Maintenance
  class RemoteEvidenceBackfillTest < ActiveSupport::TestCase
    setup do
      user = create_member!(name: "Backfill", email: "backfill-evidencias@example.com", validation_api_token: "tkn_backfill")
      @account = account_of(user)
      result = JSON.parse(file_fixture("validation_api/validation_batch_result.json").read)
      @split = completed_import!(user, "lp_batch_contract", result)
      @legacy = completed_import!(user, "lp_batch_legacy", result.merge("records" => [ { "external_id" => "1", "call_attempts" => [] } ]))
      @evidence = JSON.parse(file_fixture("validation_api/validation_batch_evidence.json").read)
    end

    test "lists only completed lots in the split format without evidence and writes nothing by default" do
      rows = RemoteEvidenceBackfill.new.call

      assert_equal [ @split.id ], rows.map { |row| row.supplier_import.id }
      assert_equal [ :pending ], rows.map(&:result)
      assert_not @split.reload.response_payload["records"].first.key?("call_attempts")
    end

    test "apply fetches and stores the evidence of each lot" do
      evidence = @evidence
      service_class = ValidationApi::Validations::ShowEvidenceService
      service_class.define_singleton_method(:new) do |*|
        Object.new.tap { |fake| fake.define_singleton_method(:call) { |**| evidence } }
      end

      begin
        rows = RemoteEvidenceBackfill.new(account: @account, apply: true).call
      ensure
        service_class.singleton_class.remove_method(:new)
      end

      assert_equal [ :applied ], rows.map(&:result)
      assert_equal 1, @split.reload.response_payload["records"].first["call_attempts"].size
      assert_equal SupplierImport::LOCAL_STATUS_COMPLETED, @split.status
      assert @split.evidence_expires_at.present?
    end

    test "preview counts changes without writing and cannot be combined with apply" do
      evidence = @evidence
      service_class = ValidationApi::Validations::ShowEvidenceService
      service_class.define_singleton_method(:new) do |*|
        Object.new.tap { |fake| fake.define_singleton_method(:call) { |**| evidence } }
      end
      original = @split.attributes.deep_dup
      begin
        rows = RemoteEvidenceBackfill.new(account: @account, preview: true).call
        assert_equal [ :would_apply ], rows.map(&:result)
        assert_equal 1, rows.sum(&:records_changed)
        assert_equal original, @split.reload.attributes
        RemoteEvidenceBackfill.new(account: @account, apply: true).call
        assert_empty RemoteEvidenceBackfill.new(account: @account, preview: true).call
      ensure
        service_class.singleton_class.remove_method(:new)
      end
      assert_raises(ArgumentError) { RemoteEvidenceBackfill.new(apply: true, preview: true) }
    end

    private

    def completed_import!(user, remote_batch_id, payload)
      SupplierImport.create!(
        account: @account || account_of(user),
        created_by: user,
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL,
        source: SupplierImport::SOURCE_UPLOAD,
        total_rows: 1,
        valid_rows: 1,
        invalid_rows: 0,
        remote_batch_id: remote_batch_id,
        validation_started_at: 1.day.ago,
        result_ready: true,
        response_payload: payload
      )
    end
  end
end
