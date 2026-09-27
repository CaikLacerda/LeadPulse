require "test_helper"

module Analytics
  class QualificationQueryTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:one)
      @user = users(:one)
      @scope = analytics_scope(@account)
      @window = @scope.filters.window
    end

    test "counts qualification outcomes and the rate by batch source" do
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 2, rejected: 1, not_answered: 1, pending_dispatch: 1))
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 1), source: SupplierImport::SOURCE_SUPPLIER_DISCOVERY)
      create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 5), workflow_kind: SupplierImport::WORKFLOW_KIND_CADASTRAL)

      outcomes = query.outcomes

      assert_equal 6, outcomes[:records]
      assert_equal 5, outcomes[:with_outcome]
      assert_equal 3, outcomes[:qualified]
      assert_equal({ "qualified_supplier" => 3, "does_not_supply_segment" => 1, "not_answered" => 1 }, outcomes[:by_outcome])
      assert_equal({ records: 5, with_outcome: 4, qualified: 2 }, outcomes[:by_source]["integracao_externa"])
      assert_equal({ records: 1, with_outcome: 1, qualified: 1 }, outcomes[:by_source]["supplier_discovery"])
    end

    test "commercial funnel follows the same batches" do
      batch = create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 2))
      old_batch = create_analytics_batch!(account: @account, started_at: brasilia(2026, 6, 1), records: analytics_records(confirmed: 1))
      create_opportunity(batch, CommercialOpportunity::STATUS_COMPLETED)
      create_opportunity(batch, CommercialOpportunity::STATUS_PENDING)
      create_opportunity(old_batch, CommercialOpportunity::STATUS_COMPLETED)

      assert_equal({ opportunities: 2, collected: 1, funnel_opportunities: 2, funnel_collected: 1, outside_funnel: 0 }, query.funnel)
    end

    test "the funnel only follows returns of records that are qualified, so no step exceeds the previous one" do
      qualified = analytics_record("confirmed")
      no_longer_qualified = analytics_record("inconclusive")
      batch = create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: [ qualified, no_longer_qualified ])
      create_opportunity(batch, CommercialOpportunity::STATUS_COMPLETED, external_id: qualified["external_id"])
      create_opportunity(batch, CommercialOpportunity::STATUS_PENDING, external_id: no_longer_qualified["external_id"])

      funnel = query.funnel

      assert_equal 2, funnel[:opportunities]
      assert_equal 1, funnel[:funnel_opportunities]
      assert_equal 1, funnel[:funnel_collected]
      assert_equal 1, funnel[:outside_funnel]
    end

    test "searches by segment with the batches they became" do
      converted = create_search("Adubo", 5)
      create_search("Adubo", 3)
      create_search("Ferro", 4)
      2.times do
        create_analytics_batch!(
          account: @account,
          started_at: brasilia(2026, 9, 21),
          source: SupplierImport::SOURCE_SUPPLIER_DISCOVERY,
          import_metadata: { "supplier_discovery_search_id" => converted.id }
        )
      end

      searches = query.searches

      assert_equal 3, searches[:searches]
      assert_equal 12, searches[:found]
      assert_equal 1, searches[:converted]
      assert_equal({ segment: "Adubo", searches: 2, found: 8, converted: 1, batches: 2 }, searches[:segments].first)
    end

    test "a review is altered only when it differs from every automatic classification" do
      kept = analytics_record("confirmed")
      changed = analytics_record("inconclusive")
      batch = create_analytics_batch!(account: @account, started_at: brasilia(2026, 9, 20), records: [ kept, changed ])
      create_review(batch, kept["external_id"], original: "confirmed", reviewed: "qualified_supplier")
      create_review(batch, changed["external_id"], original: "inconclusive", reviewed: "not_interested")
      create_review(batch, "sumiu", original: "inconclusive", reviewed: "wrong_company")

      assert_equal({ reviews: 3, altered: 1, unmatched: 1 }, query.reviews)
    end

    private

    def query
      batches = @scope.validated_batches(@window)
      QualificationQuery.new(
        batches: batches,
        opportunities: @scope.commercial_opportunities_for(batches),
        searches: @scope.discovery_searches(@window),
        discovery_batches: @scope.discovery_batches,
        reviews: @scope.audit_reviews(@window),
        review_batches: @scope.review_batches
      )
    end

    def create_opportunity(batch, status, external_id: nil)
      used = batch.commercial_opportunities.pluck(:source_external_id)
      external_id ||= batch.response_payload["records"]
        .find { |record| record.dig("supplier_validation", "outcome") == "qualified_supplier" && used.exclude?(record["external_id"]) }
        &.fetch("external_id")
      @account.commercial_opportunities.create!(
        user: @user,
        supplier_import: batch,
        source_external_id: external_id || "op-#{SecureRandom.hex(4)}",
        supplier_name: "Fornecedor",
        callback_phone: "+5511987654321",
        status: status
      )
    end

    def create_search(segment, found)
      @account.supplier_discovery_searches.create!(
        user: @user,
        search_id: "search-#{SecureRandom.hex(4)}",
        status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED,
        segment_name: segment,
        total_suppliers: found,
        created_at: brasilia(2026, 9, 21)
      )
    end

    def create_review(batch, external_id, original:, reviewed:)
      batch.audit_reviews.create!(
        user: @user,
        record_external_id: external_id,
        original_result: original,
        reviewed_result: reviewed,
        reviewed_at: brasilia(2026, 9, 22)
      )
    end
  end
end
