require "test_helper"

# Isolamento entre empresas no Analytics: com os mesmos filtros, os números de uma conta nunca
# contam lotes, registros, tentativas, retornos, buscas ou revisões de outra.
module Analytics
  class MultiTenantAnalyticsTest < ActiveSupport::TestCase
    setup do
      @cache = ActiveSupport::Cache::MemoryStore.new
      @account_a = Account.create!(name: "Empresa A")
      @account_b = Account.create!(name: "Empresa B")
      @a1 = create_member!(name: "Ana A1", email: "a1@analytics-a.test", account: @account_a)
      @a2 = create_member!(name: "Artur A2", email: "a2@analytics-a.test", account: @account_a, role: "viewer")
      @b1 = create_member!(name: "Bruno B1", email: "b1@analytics-b.test", account: @account_b)

      @batch_a1 = seed(@account_a, @a1, confirmed: 5, not_answered: 2)
      @batch_a2 = seed(@account_a, @a2, rejected: 3)
      @batch_b = seed(@account_b, @b1, inconclusive: 1)
    end

    test "every page of B only counts B" do
      report = report_for(@account_b)

      overview = report.overview
      assert_equal 1, overview[:summary].data[:metrics][:records].current.value
      assert_equal 1, overview[:summary].data[:metrics][:batches].current.value
      assert_equal [ @batch_b.id ], overview[:top_batches].data.map { |row| row[:id] }

      calls = report.calls
      assert_equal 1, calls[:summary].data[:metrics][:attempts].current.value
      assert_equal 1, calls[:by_hour].data.sum { |hour| hour[:attempts] }

      qualification = report.qualification
      assert_equal 0, qualification[:summary].data[:metrics][:qualified].current.value
      assert_equal 1, qualification[:summary].data[:metrics][:opportunities].current.value
      assert_equal 1, qualification[:searches].data[:metrics][:searches].current.value
      assert_equal 1, qualification[:reviews].data[:reviews].value

      batches = report.batches
      assert_equal 1, batches[:summary].data[:metrics][:batches].current.value
      assert_equal [ @batch_b.id ], batches[:table].data.rows.map { |row| row[:id] }
    end

    test "members of the same account see the same numbers, whoever created the batch" do
      [ @a1, @a2 ].each do
        summary = report_for(@account_a).overview[:summary].data
        assert_equal 10, summary[:metrics][:records].current.value
        assert_equal 2, summary[:metrics][:batches].current.value
      end
    end

    test "a batch id from another account in the URL is ignored" do
      report = report_for(@account_b, lote: @batch_a1.id.to_s)

      assert_nil report.filters.supplier_import_id
      assert_equal 1, report.overview[:summary].data[:metrics][:records].current.value
    end

    test "the scope refuses to run without an account" do
      assert_raises(ArgumentError) { Scope.new(account: nil, filters: analytics_filters(@account_a)) }
      assert_raises(ArgumentError) { Scope.new(account: Account.new, filters: analytics_filters(@account_a)) }
    end

    test "the cached result of A is never served to B" do
      assert_equal 10, report_for(@account_a).overview[:summary].data[:metrics][:records].current.value
      assert_equal 1, report_for(@account_b).overview[:summary].data[:metrics][:records].current.value
    end

    private

    def report_for(account, **params)
      Report.new(scope: analytics_scope(account, **params), cache: @cache)
    end

    def seed(account, user, **counts)
      records = counts.flat_map do |call_result, total|
        Array.new(total) do
          status = call_result == :not_answered ? "not_answered" : "answered"
          analytics_record(call_result.to_s, attempts: [ analytics_attempt(status, started_at: brasilia(2026, 9, 20, 10), duration: 30) ])
        end
      end
      batch = create_analytics_batch!(account: account, user: user, started_at: brasilia(2026, 9, 20, 10), records: records)

      account.commercial_opportunities.create!(user: user, supplier_import: batch, source_external_id: "op-#{SecureRandom.hex(3)}", supplier_name: "Fornecedor", callback_phone: "+5511987654321")
      account.supplier_discovery_searches.create!(user: user, search_id: "s-#{SecureRandom.hex(3)}", status: SupplierDiscoverySearch::LOCAL_STATUS_COMPLETED, segment_name: "Adubo", created_at: brasilia(2026, 9, 20))
      batch.audit_reviews.create!(user: user, record_external_id: records.first["external_id"], original_result: "confirmed", reviewed_result: "wrong_company", reviewed_at: brasilia(2026, 9, 21))
      batch
    end
  end
end
