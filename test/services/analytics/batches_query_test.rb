require "test_helper"

module Analytics
  class BatchesQueryTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
      @filters = analytics_filters(@account)
    end

    test "one row per batch with its record aggregates" do
      batch = create_analytics_batch!(
        account: @account,
        started_at: brasilia(2026, 9, 20, 10),
        records: analytics_records(confirmed: 3, rejected: 1, not_answered: 2, pending_dispatch: 1),
        total_rows: 9,
        invalid_rows: 2
      )

      row = query.page.rows.sole

      assert_equal batch.id, row[:id]
      assert_equal 7, row[:records]
      assert_equal 3, row[:validated]
      assert_equal 3, row[:confirmed]
      assert_equal 6, row[:terminal]
      assert_equal 2, row[:not_answered]
      assert_equal 2, row[:invalid_rows]
    end

    test "processing time uses the API clock and ignores the local clock" do
      create_analytics_batch!(
        account: @account,
        created_at: brasilia(2026, 9, 20, 10, 0),
        started_at: brasilia(2026, 9, 20, 10, 5),
        finished_at: brasilia(2026, 9, 20, 13, 7),
        payload: { "created_at" => "2026-09-20T13:04:00", "finished_at" => "2026-09-20T13:07:00" }
      )

      row = query.page.rows.sole

      assert_in_delta 180.0, row[:processing_seconds]
      assert_in_delta 300.0, row[:wait_seconds]
    end

    test "discards a negative processing time instead of showing it" do
      create_analytics_batch!(
        account: @account,
        started_at: brasilia(2026, 9, 20, 10),
        finished_at: brasilia(2026, 9, 20, 10, 1),
        payload: { "created_at" => "2026-09-20T13:05:00", "finished_at" => "2026-09-20T13:01:00" }
      )

      assert_nil query.page.rows.sole[:processing_seconds]
      assert_equal 0, query.summary[:with_processing]
    end

    test "summary has medians, p90 and the invalid rows" do
      [ 60, 120, 180, 240, 3600 ].each_with_index do |seconds, index|
        create_analytics_batch!(
          account: @account,
          started_at: brasilia(2026, 9, 20, 10, index),
          finished_at: brasilia(2026, 9, 20, 11),
          total_rows: 10,
          invalid_rows: index,
          payload: { "created_at" => "2026-09-20T13:00:00", "finished_at" => (Time.utc(2026, 9, 20, 13) + seconds).strftime("%Y-%m-%dT%H:%M:%S") }
        )
      end

      summary = query.summary

      assert_equal 5, summary[:batches]
      assert_equal 50, summary[:total_rows]
      assert_equal 10, summary[:invalid_rows]
      assert_equal 5, summary[:with_processing]
      assert_in_delta 180.0, summary[:median_processing]
      assert_in_delta 2256.0, summary[:p90_processing]
    end

    test "summary names the fastest and the slowest measured batch" do
      batches = [ 300, 45, 90_000 ].each_with_index.map do |seconds, index|
        create_analytics_batch!(
          account: @account, started_at: brasilia(2026, 9, 20, 10, index), finished_at: brasilia(2026, 9, 20, 11),
          payload: { "created_at" => "2026-09-20T13:00:00", "finished_at" => (Time.utc(2026, 9, 20, 13) + seconds).strftime("%Y-%m-%dT%H:%M:%S") }
        )
      end
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20, 12), finished_at: nil, payload: {})

      summary = query.summary

      assert_equal({ id: batches[1].id, seconds: 45.0 }, summary[:fastest])
      assert_equal({ id: batches[2].id, seconds: 90_000.0 }, summary[:slowest])
    end

    test "summary has no extremes without a measured batch" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20, 12), finished_at: nil, payload: {})

      assert_nil query.summary[:fastest]
      assert_nil query.summary[:slowest]
    end

    test "groups processing times into time-scale bins that add up to the measured lots" do
      [ 30, 90, 90, 400, 7200, 200_000 ].each_with_index do |seconds, index|
        create_analytics_batch!(
          account: @account, started_at: brasilia(2026, 9, 20, 10, index), finished_at: brasilia(2026, 9, 20, 11),
          payload: { "created_at" => "2026-09-20T13:00:00", "finished_at" => (Time.utc(2026, 9, 20, 13) + seconds).strftime("%Y-%m-%dT%H:%M:%S") }
        )
      end

      bins = query.summary[:processing_bins].to_h

      assert_equal({ "under_1m" => 1, "1m_3m" => 2, "3m_10m" => 1, "10m_1h" => 0, "1h_1d" => 1, "over_1d" => 1 }, bins)
      assert_equal query.summary[:with_processing], bins.values.sum
    end

    test "sorts only by allowed columns and clamps the page" do
      small = create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 1))
      large = create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 21), records: analytics_records(confirmed: 3))

      assert_equal [ large.id, small.id ], query.page(sort: "registros", direction: "desc").rows.map { |row| row[:id] }
      assert_equal [ small.id, large.id ], query.page(sort: "registros", direction: "asc").rows.map { |row| row[:id] }

      fallback = query.page(sort: "id; DROP TABLE users", direction: "sideways")
      assert_equal "criado_em", fallback.sort
      assert_equal "desc", fallback.direction

      paged = query.page(page: 99, per_page: 1)
      assert_equal 2, paged.page
      assert_equal 2, paged.total_pages
      assert_equal [ small.id ], paged.rows.map { |row| row[:id] }
    end

    private

    def query
      BatchesQuery.new(analytics_scope(@account).created_batches(@filters.window))
    end
  end
end
