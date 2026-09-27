require "test_helper"

module Tenancy
  class IntegrityCheckTest < ActiveSupport::TestCase
    test "accepts consistent data" do
      assert_empty IntegrityCheck.new.call
    end

    test "reports a lot child stored in another account" do
      batch = create_analytics_batch!(account: accounts(:one), started_at: 1.day.ago)
      review = batch.audit_reviews.create!(user: users(:one), reviewed_result: "wrong_company", reviewed_at: Time.current)
      review.update_columns(account_id: accounts(:two).id)

      problems = IntegrityCheck.new.call

      assert_equal [ [ "empresa diferente da do lote", "audit_reviews", 1 ] ], problems.map { |problem| [ problem.check, problem.table, problem.count ] }
    end
  end
end
