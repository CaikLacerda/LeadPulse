require "test_helper"

module Maintenance
  class FinishedAtCorrectionPreviewTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @account = account_of(@user)
    end

    test "proposes the UTC reading for a value saved without offset and changes nothing" do
      supplier_import = create_import(
        validation_started_at: Time.utc(2026, 7, 24, 18, 3, 56),
        finished_at: "2026-07-24T18:06:15.707406",
        payload_finished_at: "2026-07-24T18:06:15.707406"
      )
      stored = supplier_import.reload.finished_at

      row = FinishedAtCorrectionPreview.new(account: @account).call.find { |item| item.id == supplier_import.id }

      assert_equal Time.utc(2026, 7, 24, 21, 6, 15.707406r), stored
      assert_equal Time.utc(2026, 7, 24, 18, 6, 15.707406r), row.new_value
      assert_equal(-3.hours, row.difference)
      assert row.change?
      assert_empty row.anomalies
      assert_equal stored, supplier_import.reload.finished_at
    end

    test "keeps a value that already had an offset and flags an implausible duration" do
      supplier_import = create_import(
        validation_started_at: Time.utc(2026, 6, 10, 13, 37, 8),
        finished_at: Time.utc(2026, 9, 14, 16, 55, 36),
        payload_finished_at: "2026-09-14T16:55:36Z"
      )

      row = FinishedAtCorrectionPreview.new(account: @account).call.find { |item| item.id == supplier_import.id }

      assert_not row.change?
      assert_equal 0, row.difference
      assert_includes row.anomalies.join, "duração acima"
    end

    test "only reads the given account" do
      create_import(validation_started_at: 1.hour.ago, finished_at: 30.minutes.ago, payload_finished_at: "2026-07-24T18:06:15")

      assert_empty FinishedAtCorrectionPreview.new(account: accounts(:two)).call
    end

    private

    def create_import(validation_started_at:, finished_at:, payload_finished_at:)
      @account.supplier_imports.create!(
        created_by: @user,
        status: SupplierImport::LOCAL_STATUS_COMPLETED,
        workflow_kind: SupplierImport::WORKFLOW_KIND_SUPPLIER,
        source: SupplierImport::SOURCE_UPLOAD,
        created_at: validation_started_at - 5.seconds,
        validation_started_at: validation_started_at,
        finished_at: finished_at,
        response_payload: { "batch_status" => "completed", "finished_at" => payload_finished_at, "records" => [] }
      )
    end
  end
end
