require "test_helper"

module Analytics
  class AttemptsQueryTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
      @filters = analytics_filters(@account)
    end

    test "duration uses only answered calls that report it, with the coverage" do
      create_analytics_batch!(
        account: @account,
        started_at: brasilia(2026, 9, 20, 9),
        records: [
          analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 9, 20, 9), duration: 30) ]),
          analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 9, 20, 9), duration: 60) ]),
          analytics_record("inconclusive", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 9, 20, 9), duration: nil) ]),
          analytics_record("not_answered", attempts: [ analytics_attempt("not_answered", started_at: brasilia(2026, 9, 20, 9), duration: 0) ]),
          analytics_record("inconclusive", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 9, 20, 9), duration: "abc") ])
        ]
      )

      summary = query.summary

      assert_equal 5, summary[:attempts]
      assert_equal 4, summary[:answered]
      assert_equal 2, summary[:with_duration]
      assert_in_delta 45.0, summary[:average_duration]
      assert_in_delta 45.0, summary[:median_duration]
      coverage = Metric.rate(summary[:with_duration], summary[:answered])
      assert_in_delta 0.5, coverage.value
    end

    test "answer rate counts answered, not answered and failed calls only" do
      attempts = %w[answered answered not_answered failed queued].map { |status| analytics_attempt(status, started_at: brasilia(2026, 9, 20, 9)) }
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20, 9), records: attempts.map { |attempt| analytics_record("inconclusive", attempts: [ attempt ]) })

      summary = query.summary

      assert_equal 5, summary[:attempts]
      assert_equal 4, summary[:answer_base]
      assert_equal 1, summary[:other_status]
      assert_in_delta 0.5, Metric.rate(summary[:answered], summary[:answer_base]).value
    end

    test "places each attempt by its own time, in Brasília" do
      batch_started = brasilia(2026, 8, 26, 23, 50)
      create_analytics_batch!(
        account: @account,
        started_at: batch_started,
        records: [
          analytics_record("not_answered", attempts: [ analytics_attempt("not_answered", started_at: brasilia(2026, 8, 26, 23, 55)) ]),
          analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 8, 27, 0, 5)) ])
        ]
      )

      summary = query.summary
      hours = query.by_hour

      assert_equal 1, summary[:attempts]
      assert_equal 1, summary[:answered]
      assert_equal 24, hours.size
      assert_equal 1, hours[0][:attempts]
      assert_equal 0, hours[23][:attempts]
    end

    test "reads attempt times like the API parser: no offset is UTC, explicit offsets are kept" do
      times = [ "2026-09-20T17:10:00Z", "2026-09-20T14:10:00-03:00", "2026-09-20T12:10:00.123456", "sem horário" ]
      records = times.map do |time|
        analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 9, 20)).merge("started_at" => time) ])
      end
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20, 8), records: records)

      hours = query.by_hour

      assert_equal 2, hours[14][:attempts]
      assert_equal 1, hours[9][:attempts]
      assert_equal 3, hours.sum { |hour| hour[:attempts] }
    end

    test "daily rows carry the median duration of each day" do
      create_analytics_batch!(
        account: @account,
        started_at: brasilia(2026, 9, 24, 9),
        records: [
          analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 9, 24, 9), duration: 20) ]),
          analytics_record("confirmed", attempts: [ analytics_attempt("answered", started_at: brasilia(2026, 9, 24, 10), duration: 40) ]),
          analytics_record("not_answered", attempts: [ analytics_attempt("not_answered", started_at: brasilia(2026, 9, 25, 9)) ])
        ]
      )

      rows = query.daily("dia")

      assert_equal 30, rows.size
      day = rows.find { |row| row[:date] == Date.new(2026, 9, 24) }
      assert_equal 2, day[:attempts]
      assert_in_delta 30.0, day[:median_duration]
      assert_nil rows.find { |row| row[:date] == Date.new(2026, 9, 25) }[:median_duration]
    end

    private

    def query
      AttemptsQuery.new(analytics_scope(@account).attempt_batches(@filters.window), @filters.window)
    end
  end
end
