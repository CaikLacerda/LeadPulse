require "test_helper"

module Analytics
  class ReportTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
      @user = users(:one)
      @cache = ActiveSupport::Cache::MemoryStore.new
    end

    test "compares counts in percent and rates in points when both samples are large enough" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 15, rejected: 15))
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 8, 10), records: analytics_records(confirmed: 10, rejected: 15))

      metrics = report.overview[:summary].data[:metrics]

      assert_equal :ok, metrics[:records].status
      assert_in_delta 0.2, metrics[:records].delta
      assert_equal :ok, metrics[:confirmation_rate].status
      assert_in_delta 0.5, metrics[:confirmation_rate].current.value
      assert_in_delta 0.1, metrics[:confirmation_rate].delta
    end

    test "keeps a small sample visible but never as a conclusive variation" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 5, rejected: 3))
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 8, 10), records: analytics_records(confirmed: 1, rejected: 3))

      rate = report.overview[:summary].data[:metrics][:confirmation_rate]

      assert_in_delta 0.625, rate.current.value
      assert_equal 8, rate.current.sample
      assert rate.current.low_sample?
      assert_equal :low_sample, rate.status
      assert_not rate.conclusive?
    end

    test "shows no base instead of an infinite variation" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 25))

      metrics = report.overview[:summary].data[:metrics]

      assert_equal :no_base, metrics[:records].status
      assert_nil metrics[:records].delta
      assert_equal :no_base, metrics[:confirmation_rate].status
    end

    test "without comparison only the current window is read" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 2))

      page = report(comparar: "nenhum").overview

      assert_equal :unavailable, page[:summary].data[:metrics][:records].status
      assert_nil page[:evolution].data[:previous_totals]
    end

    test "evolution aligns the previous window by position" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 19, 12), records: analytics_records(confirmed: 2))
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 12, 12), records: analytics_records(rejected: 3))

      evolution = report(periodo: "7d").overview[:evolution].data

      assert_equal 7, evolution[:rows].size
      assert_equal 2, evolution[:rows].first[:records]
      assert_equal [ 3, 0, 0, 0, 0, 0, 0 ], evolution[:previous_totals]
    end

    test "a failing section does not take the page down and is logged with the account" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 2))
      log = StringIO.new

      page = with_failing_series do
        Report.new(scope: analytics_scope(@account), cache: @cache, logger: Logger.new(log)).overview
      end

      assert page[:evolution].failed?
      assert_nil page[:evolution].data
      assert_not page[:summary].failed?
      assert_equal 2, page[:summary].data[:metrics][:records].current.value
      assert_match "overview.evolution", log.string
      assert_match "account_id=#{@account.id}", log.string
      assert_no_match(/Fornecedor|\+55/, log.string)
    end

    test "runs each section with a statement timeout" do
      timeout = report.send(:with_statement_timeout) { ActiveRecord::Base.connection.select_value("SHOW statement_timeout") }

      assert_equal Report::STATEMENT_TIMEOUT, timeout
    end

    test "cache follows the sources each section reads" do
      batch = create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 2))
      assert_equal 0, report.qualification[:summary].data[:metrics][:opportunities].current.value
      assert_equal 0, report.qualification[:reviews].data[:reviews].value
      assert_equal 0, report.qualification[:searches].data[:metrics][:searches].current.value

      @account.commercial_opportunities.create!(supplier_import: batch, source_external_id: "op-1", supplier_name: "Fornecedor", callback_phone: "+5511987654321")
      assert_equal 1, report.qualification[:summary].data[:metrics][:opportunities].current.value

      batch.audit_reviews.create!(reviewed_by: @user, record_external_id: "x", original_result: "confirmed", reviewed_result: "wrong_company", reviewed_at: brasilia(2026, 9, 21))
      assert_equal 1, report.qualification[:reviews].data[:reviews].value

      @account.supplier_discovery_searches.create!(created_by: @user, search_id: "s-1", status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED, segment_name: "Adubo", created_at: brasilia(2026, 9, 21))
      assert_equal 1, report.qualification[:searches].data[:metrics][:searches].current.value

      assert_equal 2, report.overview[:summary].data[:metrics][:records].current.value
      batch.update!(response_payload: { "records" => analytics_records(confirmed: 3) })
      assert_equal 3, report.overview[:summary].data[:metrics][:records].current.value
    end

    test "cache is isolated by account even with the same filters" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 4))
      other = accounts(:two)
      create_analytics_batch!(account: other, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 1))

      assert_equal 4, report.overview[:summary].data[:metrics][:records].current.value
      other_report = Report.new(scope: analytics_scope(other), cache: @cache)
      assert_equal 1, other_report.overview[:summary].data[:metrics][:records].current.value
    end

    private

    def report(**params)
      Report.new(scope: analytics_scope(@account, **params), cache: @cache)
    end

    def with_failing_series
      original = RecordsQuery.instance_method(:series)
      RecordsQuery.define_method(:series) { |*| raise ActiveRecord::StatementInvalid, "canceling statement due to statement timeout" }
      yield
    ensure
      RecordsQuery.define_method(:series, original)
    end
  end
end
