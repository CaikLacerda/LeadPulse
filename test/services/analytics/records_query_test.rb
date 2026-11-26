require "test_helper"

module Analytics
  class RecordsQueryTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
    end

    test "counts records by result and excludes pending ones from the terminal base" do
      create_analytics_batch!(
        account: @account,
        started_at: brasilia(2026, 9, 20, 10),
        records: analytics_records(confirmed: 4, not_answered: 3, inconclusive: 2, pending_dispatch: 1)
      )

      summary = RecordsQuery.new(analytics_scope(@account).validated_batches(analytics_filters(@account).window)).summary

      assert_equal 1, summary[:batches]
      assert_equal 10, summary[:records]
      assert_equal 4, summary[:validated]
      assert_equal 5, summary[:not_validated]
      assert_equal 1, summary[:processing]
      assert_equal 9, summary[:terminal]
      assert_equal({ "confirmed" => 4, "rejected" => 0, "inconclusive" => 2, "not_answered" => 3, "pending_dispatch" => 1, "other" => 0 }, summary[:results])
      assert_equal 9, summary[:called]
      assert_equal 6, summary[:answered]

      rate = Metric.rate(summary[:results]["confirmed"], summary[:terminal])
      assert_in_delta 0.444, rate.value, 0.001
      assert_equal 9, rate.sample
    end

    test "a record on the last day at 23:59 in Brasília counts and at midnight it does not" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 25, 23, 59), records: analytics_records(confirmed: 1))
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 26, 0, 0), records: analytics_records(confirmed: 1))
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 8, 27, 0, 0), records: analytics_records(rejected: 1))
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 8, 26, 23, 59), records: analytics_records(rejected: 1))

      summary = RecordsQuery.new(analytics_scope(@account).validated_batches(analytics_filters(@account).window)).summary

      assert_equal 2, summary[:records]
      assert_equal 1, summary[:results]["confirmed"]
      assert_equal 1, summary[:results]["rejected"]
    end

    test "workflow, source and batch filters change the numbers" do
      upload = create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 2))
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(rejected: 3), source: SupplierImport::SOURCE_SUPPLIER_DISCOVERY)
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(inconclusive: 1), workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL)

      count = lambda do |**params|
        scope = analytics_scope(@account, **params)
        RecordsQuery.new(scope.validated_batches(scope.filters.window)).summary[:records]
      end

      assert_equal 6, count.call
      assert_equal 3, count.call(origem: "supplier_discovery")
      assert_equal 5, count.call(fluxo: "supplier_validation")
      assert_equal 1, count.call(fluxo: "cadastral_validation")
      assert_equal 2, count.call(lote: upload.id.to_s)
    end

    test "tolerates missing keys and malformed payloads" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: [ {}, { "call_result" => "novo_codigo", "attempts_count" => "muitas" }, "texto solto" ])
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), payload: { "records" => { "quebrado" => true } })
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), payload: { "records" => [] })

      summary = RecordsQuery.new(analytics_scope(@account).validated_batches(analytics_filters(@account).window)).summary

      assert_equal 3, summary[:batches]
      assert_equal 2, summary[:awaiting_sync]
      assert_equal 3, summary[:records]
      assert_equal 3, summary[:results]["other"]
      assert_equal 0, summary[:terminal]
      assert_equal 0, summary[:attempts_reported]
    end

    test "counts a privacy refusal found in the record or in an attempt" do
      create_analytics_batch!(
        account: @account,
        started_at: brasilia(2026, 9, 20),
        records: [
          analytics_record("rejected", privacy_refusal_detected: true),
          analytics_record("inconclusive", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 9, 20), privacy_refusal_detected: true) ]),
          analytics_record("confirmed")
        ]
      )

      summary = RecordsQuery.new(analytics_scope(@account).validated_batches(analytics_filters(@account).window)).summary

      assert_equal 2, summary[:privacy_refusals]
    end

    test "daily series fills empty days with zero" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 24, 23, 30), records: analytics_records(confirmed: 2, not_answered: 1))
      window = analytics_filters(@account, periodo: "7d").window

      series = RecordsQuery.new(analytics_scope(@account, periodo: "7d").validated_batches(window)).series(window, "dia")

      assert_equal 7, series.size
      assert_equal (Date.new(2026, 9, 19)..Date.new(2026, 9, 25)).to_a, series.map { |row| row[:date] }
      day = series.find { |row| row[:date] == Date.new(2026, 9, 24) }
      assert_equal({ records: 3, confirmed: 2, rejected: 0, inconclusive: 0, not_answered: 1, other: 0 }, day.except(:date))
      assert_equal 3, series.sum { |row| row[:records] }
    end
  end
end
