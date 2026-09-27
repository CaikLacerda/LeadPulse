# Etapa D do tenancy por conta: com a aplicação já gravando account_id (fase 5), a coluna
# passa a ser obrigatória no banco. Antes, completa registros criados entre as fases e confere
# a consistência com o lote. Reversível e sem remoção de dados; user_id continua intacto.
class RequireAccountIdOnBusinessTables < ActiveRecord::Migration[8.1]
  TABLES_BY_CREATOR = %w[
    supplier_imports
    supplier_discovery_searches
    audit_reviews
    privacy_requests
    privacy_audit_events
    third_party_operators
  ].freeze
  TABLES_WITH_SUPPLIER_IMPORT = %w[commercial_opportunities audit_reviews privacy_requests privacy_audit_events].freeze
  ALL_TABLES = (TABLES_BY_CREATOR + %w[commercial_opportunities]).freeze

  def up
    TABLES_BY_CREATOR.each do |table|
      execute <<~SQL.squish
        UPDATE #{table} t SET account_id = m.account_id
        FROM account_memberships m
        WHERE t.account_id IS NULL AND m.user_id = t.user_id
          AND (SELECT COUNT(*) FROM account_memberships mm WHERE mm.user_id = t.user_id) = 1
      SQL
    end
    execute <<~SQL.squish
      UPDATE commercial_opportunities co SET account_id = si.account_id
      FROM supplier_imports si
      WHERE co.account_id IS NULL AND si.id = co.supplier_import_id
    SQL

    ALL_TABLES.each do |table|
      missing = select_value("SELECT COUNT(*) FROM #{table} WHERE account_id IS NULL").to_i
      raise "#{table}: #{missing} registro(s) sem conta; NOT NULL não aplicado." if missing.positive?
    end

    TABLES_WITH_SUPPLIER_IMPORT.each do |table|
      mismatched = select_value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM #{table} t
        JOIN supplier_imports si ON si.id = t.supplier_import_id
        WHERE t.account_id <> si.account_id
      SQL
      raise "#{table}: #{mismatched} registro(s) em conta diferente da conta do lote." if mismatched.positive?
    end

    ALL_TABLES.each { |table| change_column_null table, :account_id, false }
  end

  def down
    ALL_TABLES.each { |table| change_column_null table, :account_id, true }
  end
end
