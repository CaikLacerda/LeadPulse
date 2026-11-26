require "test_helper"

module ValidationApi
  class TimestampTest < ActiveSupport::TestCase
    test "reads a value without offset as UTC" do
      parsed = Timestamp.parse("2026-07-21T17:34:15.088290")

      assert_equal Time.utc(2026, 7, 21, 17, 34, 15.088290r), parsed
      assert_equal "21/07/2026 14:34", parsed.in_time_zone("America/Sao_Paulo").strftime("%d/%m/%Y %H:%M")
    end

    test "keeps an explicit offset" do
      assert_equal Time.utc(2026, 7, 21, 17, 34, 15), Timestamp.parse("2026-07-21T17:34:15Z")
      assert_equal Time.utc(2026, 7, 21, 17, 34, 15), Timestamp.parse("2026-07-21T17:34:15+00:00")
      assert_equal Time.utc(2026, 7, 21, 20, 34, 15), Timestamp.parse("2026-07-21T17:34:15-03:00")
    end

    test "does not mistake a date for an offset" do
      assert_equal Time.utc(2026, 7, 21), Timestamp.parse("2026-07-21")
    end

    test "returns the application zone" do
      assert_equal Time.zone, Timestamp.parse("2026-07-21T17:34:15").time_zone
    end

    test "passes times through and ignores blank or invalid values" do
      time = Time.utc(2026, 7, 21, 17, 34, 15)

      assert_equal time, Timestamp.parse(time)
      assert_nil Timestamp.parse(nil)
      assert_nil Timestamp.parse("")
      assert_nil Timestamp.parse("sem data")
    end
  end
end
