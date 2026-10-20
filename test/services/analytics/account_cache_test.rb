require "test_helper"

# O cache do Analytics é da empresa: membros da mesma empresa usam a mesma entrada, e
# nenhuma chave carrega dado de usuário.
module Analytics
  class AccountCacheTest < ActiveSupport::TestCase
    setup do
      @cache = ActiveSupport::Cache::MemoryStore.new
      @account = Account.create!(name: "Empresa A")
      @admin = create_member!(name: "Ana", email: "ana@cache-a.test", account: @account, role: "admin")
      @operator = create_member!(name: "Otto", email: "otto@cache-a.test", account: @account, role: "operator")
      create_analytics_batch!(account: @account, user: @admin, started_at: brasilia(2026, 9, 20), records: analytics_records(confirmed: 3))
    end

    test "members of the same account share the cached sections" do
      Report.new(scope: analytics_scope(@account), cache: @cache).overview
      keys = cache_keys

      assert keys.any?
      assert keys.all? { |key| key.include?("/#{@account.id}/") }, keys.inspect
      assert keys.none? { |key| key.include?(@admin.email) || key.include?(@operator.email) || key.match?(/user/i) }

      queries = count_queries { Report.new(scope: analytics_scope(@account), cache: @cache).overview }
      assert_equal keys, cache_keys, "o segundo membro reaproveita as mesmas entradas"
      assert_operator queries, :<=, 1, "só a versão das fontes é consultada; as seções vêm do cache"
    end

    private

    def cache_keys
      @cache.instance_variable_get(:@data).keys.sort
    end

    def count_queries(&block)
      count = 0
      callback = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:sql].start_with?("SAVEPOINT", "RELEASE", "ROLLBACK") }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
      count
    end
  end
end
