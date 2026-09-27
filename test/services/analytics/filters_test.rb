require "test_helper"

module Analytics
  class FiltersTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
      @today = Date.new(2026, 9, 25)
    end

    test "defaults to the last 30 whole days compared with the 30 days before" do
      filters = analytics_filters(@account)

      assert_equal Date.new(2026, 8, 27), filters.window.first_day
      assert_equal @today, filters.window.last_day
      assert_equal 30, filters.window.days
      assert_equal Date.new(2026, 7, 28), filters.previous_window.first_day
      assert_equal Date.new(2026, 8, 26), filters.previous_window.last_day
      assert_equal "27 ago – 25 set 2026", filters.window.label
      assert_equal({}, filters.to_params)
    end

    test "window bounds are whole days in Brasília" do
      window = analytics_filters(@account, periodo: "7d").window

      assert_equal brasilia(2026, 9, 19), window.starts_at
      assert_equal brasilia(2026, 9, 26), window.ends_at
      assert window.range.cover?(brasilia(2026, 9, 25, 23, 59, 59))
      assert_not window.range.cover?(brasilia(2026, 9, 26))
    end

    test "values outside the allowed lists fall back to the defaults" do
      filters = analytics_filters(@account, periodo: "5y", comparar: "sempre", fluxo: "outro", origem: "x", status: "apagado", direcao: "sideways", ordem: "id; DROP TABLE users", page: "-3")

      assert_equal "30d", filters.period
      assert_equal "anterior", filters.comparison
      assert_nil filters.workflow_kind
      assert_nil filters.source
      assert_nil filters.status
      assert_nil filters.direction
      assert_nil filters.sort
      assert_equal 1, filters.page
      assert_empty filters.adjustments
    end

    test "custom period is inclusive, ordered and limited to today" do
      filters = analytics_filters(@account, periodo: "personalizado", de: "2026-12-01", ate: "2026-09-01")

      assert_equal Date.new(2026, 9, 1), filters.window.first_day
      assert_equal @today, filters.window.last_day
      assert_equal({ periodo: "personalizado", de: "2026-09-01", ate: "2026-09-25" }, filters.to_params)
    end

    test "custom period above 366 days is refused" do
      filters = analytics_filters(@account, periodo: "personalizado", de: "2025-01-01", ate: "2026-09-25")

      assert_equal "30d", filters.period
      assert_equal 30, filters.window.days
      assert_equal [ :custom_period_too_long ], filters.adjustments
    end

    test "previous year compares the same dates twelve months before" do
      filters = analytics_filters(@account, periodo: "7d", comparar: "ano_anterior")

      assert_equal Date.new(2025, 9, 19), filters.previous_window.first_day
      assert_equal Date.new(2025, 9, 25), filters.previous_window.last_day
    end

    test "no comparison has no previous window" do
      assert_not analytics_filters(@account, comparar: "nenhum").compare?
    end

    test "groups by week above 92 days and weeks start on Monday" do
      filters = analytics_filters(@account, periodo: "12m")

      assert_equal "semana", filters.grouping
      assert filters.window.buckets("semana").all?(&:monday?)
      assert_equal "dia", analytics_filters(@account, periodo: "90d").grouping
      assert_equal "semana", analytics_filters(@account, periodo: "30d", agrupar: "semana").grouping
    end

    test "only accepts a batch of the same account" do
      own = create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20))
      foreign = create_analytics_batch!(account: accounts(:two), started_at: brasilia(2026, 9, 20))

      assert_equal own.id, analytics_filters(@account, lote: own.id.to_s).supplier_import_id
      assert_nil analytics_filters(@account, lote: foreign.id.to_s).supplier_import_id
      assert_nil analytics_filters(@account, lote: "1 OR 1=1").supplier_import_id
    end

    test "cache key changes with the filters and with the day" do
      base = analytics_filters(@account).cache_key

      assert_not_equal base, analytics_filters(@account, fluxo: "supplier_validation").cache_key
      assert_not_equal base, analytics_filters(@account, today: @today + 1).cache_key
      assert_equal base, analytics_filters(@account, ordem: "registros").cache_key
      assert_not_equal base, analytics_filters(@account, ordem: "registros").cache_key(table: true)
    end
  end
end
