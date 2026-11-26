# Fase 4 do tenancy por conta: as entidades da empresa ganham account_id.
#
# - A coluna nasce nullable: o código só passa a preenchê-la na fase 5, e o NOT NULL vem
#   numa migração posterior, depois que a aplicação já grava a conta.
# - Backfill pela conta do usuário que criou o registro (cada usuário tem exatamente um
#   vínculo nesta etapa). Retornos comerciais herdam a conta do lote de origem.
# - Ao final, confere que todo registro ligado a um lote está na mesma conta do lote.
# - user_id continua existindo e passa a significar "quem fez" (criou, revisou, registrou).
class AddAccountIdToBusinessTables < ActiveRecord::Migration[8.1]
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
    ALL_TABLES.each do |table|
      add_reference table, :account, null: true, index: true
    end

    ensure_single_membership_per_user!

    TABLES_BY_CREATOR.each do |table|
      updated = exec_update(<<~SQL.squish)
        UPDATE #{table} t SET account_id = m.account_id
        FROM account_memberships m
        WHERE m.user_id = t.user_id AND t.account_id IS NULL
      SQL
      say "#{table}: #{updated} registro(s) associados à conta"
    end

    updated = exec_update(<<~SQL.squish)
      UPDATE commercial_opportunities co SET account_id = si.account_id
      FROM supplier_imports si
      WHERE si.id = co.supplier_import_id AND co.account_id IS NULL
    SQL
    say "commercial_opportunities: #{updated} registro(s) associados à conta"

    ensure_complete_and_consistent!

    ALL_TABLES.each do |table|
      add_foreign_key table, :accounts, validate: false
      validate_foreign_key table, :accounts
    end

    # Uma revisão humana por registro/tentativa em cada empresa (antes era por usuário).
    add_index :audit_reviews,
      [ :account_id, :supplier_import_id, :record_external_id, :provider_call_id, :attempt_number ],
      unique: true, name: "index_audit_reviews_on_account_lookup"
  end

  def down
    remove_index :audit_reviews, name: "index_audit_reviews_on_account_lookup"

    ALL_TABLES.each do |table|
      remove_foreign_key table, :accounts
      remove_reference table, :account, index: true
    end
  end

  private

  def ensure_single_membership_per_user!
    ambiguous = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*) FROM (
        SELECT user_id FROM account_memberships GROUP BY user_id HAVING COUNT(*) > 1
      ) duplicated
    SQL
    return if ambiguous.zero?

    raise "#{ambiguous} usuário(s) com mais de uma conta: o backfill por usuário seria ambíguo."
  end

  def ensure_complete_and_consistent!
    ALL_TABLES.each do |table|
      missing = select_value("SELECT COUNT(*) FROM #{table} WHERE account_id IS NULL").to_i
      raise "#{table}: #{missing} registro(s) sem conta após o backfill." if missing.positive?
    end

    TABLES_WITH_SUPPLIER_IMPORT.each do |table|
      mismatched = select_value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM #{table} t
        JOIN supplier_imports si ON si.id = t.supplier_import_id
        WHERE t.account_id <> si.account_id
      SQL
      raise "#{table}: #{mismatched} registro(s) em conta diferente da conta do lote." if mismatched.positive?
    end
  end
end
