module Tenancy
  # Verificação de integridade do tenancy por empresa. Só lê; devolve a lista de problemas.
  #
  # - todo dado de negócio tem account_id;
  # - dado ligado a um lote está na mesma empresa do lote;
  # - toda empresa com vínculos ativos tem um administrador ativo.
  class IntegrityCheck
    ACCOUNT_TABLES = %w[
      supplier_imports supplier_discovery_searches commercial_opportunities audit_reviews
      privacy_requests privacy_audit_events third_party_operators account_invitations analytics_api_tokens
    ].freeze
    LOT_CHILD_TABLES = %w[commercial_opportunities audit_reviews privacy_requests privacy_audit_events].freeze

    Problem = Data.define(:check, :table, :count)

    def call
      problems = []
      connection = ActiveRecord::Base.connection

      existing(ACCOUNT_TABLES).each do |table|
        count = connection.select_value("SELECT COUNT(*) FROM #{table} WHERE account_id IS NULL").to_i
        problems << Problem.new(check: "sem account_id", table: table, count: count) if count.positive?
      end

      existing(LOT_CHILD_TABLES).each do |table|
        count = connection.select_value(<<~SQL).to_i
          SELECT COUNT(*) FROM #{table} t JOIN supplier_imports si ON si.id = t.supplier_import_id
          WHERE t.account_id <> si.account_id
        SQL
        problems << Problem.new(check: "empresa diferente da do lote", table: table, count: count) if count.positive?
      end

      without_admin = connection.select_value(<<~SQL).to_i
        SELECT COUNT(*) FROM accounts a
        WHERE EXISTS (SELECT 1 FROM account_memberships m WHERE m.account_id = a.id AND m.status = 'active')
          AND NOT EXISTS (SELECT 1 FROM account_memberships m WHERE m.account_id = a.id AND m.status = 'active' AND m.role = 'admin')
      SQL
      problems << Problem.new(check: "empresa sem admin ativo", table: "accounts", count: without_admin) if without_admin.positive?

      problems
    end

    private

    def existing(tables)
      tables & ActiveRecord::Base.connection.tables
    end
  end
end
