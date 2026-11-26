require "test_helper"

module Maintenance
  class FinishedAtCorrectionTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
      @dir = Rails.root.join("tmp/test-backups-#{SecureRandom.hex(4)}")
    end

    teardown do
      FileUtils.rm_rf(@dir)
    end

    test "corrects only rows whose stored value is the old reading of the payload" do
      safe = create_import("2026-07-24T18:06:15.707406", created: Time.utc(2026, 7, 24, 18, 3), started: Time.utc(2026, 7, 24, 18, 3, 56))
      before_start = create_import("2026-07-24T18:17:40.670731", created: Time.utc(2026, 7, 24, 18, 15), started: Time.utc(2026, 7, 24, 18, 19, 40))
      already_right = create_import("2026-09-14T16:55:36Z", created: Time.utc(2026, 6, 10), started: Time.utc(2026, 6, 10))

      result = FinishedAtCorrection.new(backup_dir: @dir).call

      assert_equal [ safe.id ], result.applied.map(&:id)
      assert_equal Time.utc(2026, 7, 24, 18, 6, 15.707406r), safe.reload.finished_at
      assert_equal Time.zone.parse("2026-07-24T18:17:40.670731"), before_start.reload.finished_at
      assert_equal Time.utc(2026, 9, 14, 16, 55, 36), already_right.reload.finished_at
      assert_includes result.kept.map(&:id), before_start.id

      backup = JSON.parse(File.read(result.backup_path))
      assert_equal [ safe.display_code ], backup.map { |entry| entry["code"] }

      FinishedAtCorrection.restore(result.backup_path)
      assert_equal Time.zone.parse("2026-07-24T18:06:15.707406"), safe.reload.finished_at
    end

    private

    # Grava finished_at como o parser antigo gravava: horário sem fuso lido como Brasília.
    def create_import(payload_finished_at, created:, started:)
      create_analytics_batch!(
        account: @account,
        created_at: created,
        started_at: started,
        finished_at: Time.zone.parse(payload_finished_at),
        payload: { "finished_at" => payload_finished_at }
      )
    end
  end
end
