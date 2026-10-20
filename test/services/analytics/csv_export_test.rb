require "test_helper"
require "csv"

module Analytics
  class CsvExportTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
      attempts = [ analytics_attempt("answered", started_at: brasilia(2026, 9, 20, 10), duration: 42.6) ]
      @batch = create_analytics_batch!(
        account: @account,
        started_at: brasilia(2026, 9, 20, 10),
        records: [ analytics_record("confirmed", attempts: attempts, external_id: "ext-1", client_name: "@SUM(1)", cnpj_original: "12.345.678/0001-95") ]
      )
    end

    test "records CSV keeps a stable contract with codes, UTC dates and a BOM" do
      lines = CsvExport.new(scope: analytics_scope(@account), dataset: "registros", generated_at: brasilia(2026, 9, 25)).each.to_a

      assert lines.first.start_with?("﻿")
      csv = CSV.parse(lines.join.delete_prefix("﻿"), headers: true)
      assert_equal CsvExport::RECORD_COLUMNS, csv.headers
      row = csv.first
      assert_equal @batch.display_code, row["batch_code"]
      assert_equal "ext-1", row["record_external_id"]
      assert_equal "'@SUM(1)", row["company_name"]
      assert_equal "confirmed", row["call_result"]
      assert_equal "qualified_supplier", row["qualification_outcome"]
      assert_equal "2026-09-20T13:00:00Z", row["validation_started_at"]
      assert_equal "false", row["privacy_refusal_detected"]
      assert_equal "43", row["answered_duration_seconds"]
      assert_nil row["phone_belongs_to_company"]
    end

    test "attempts CSV has one line per attempt in the period" do
      export = CsvExport.new(scope: analytics_scope(@account), dataset: "chamadas", generated_at: brasilia(2026, 9, 25))
      csv = CSV.parse(export.each.to_a.join.delete_prefix("﻿"), headers: true)

      assert_equal "leadpulse_analytics_chamadas_2026-09-25.csv", export.filename
      assert_equal CsvExport::ATTEMPT_COLUMNS, csv.headers
      assert_equal 1, csv.size
      assert_equal "answered", csv.first["status"]
      assert_equal "2026-09-20T13:00:00Z", csv.first["started_at"]
    end

    test "never includes phones, transcripts or recordings" do
      %w[registros chamadas].each do |dataset|
        content = CsvExport.new(scope: analytics_scope(@account), dataset: dataset).each.to_a.join

        assert_no_match(/\+55|gravacao|texto/, content, dataset)
      end
    end

    test "only reads the given account" do
      content = CsvExport.new(scope: analytics_scope(accounts(:two)), dataset: "registros").each.to_a

      assert_equal 1, content.size
    end
  end
end
