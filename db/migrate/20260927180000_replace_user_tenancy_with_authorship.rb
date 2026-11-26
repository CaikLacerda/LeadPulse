# Fase 13 do tenancy final: user_id deixa de existir nas tabelas de negócio.
#
# - A empresa (account_id, NOT NULL) é a dona de cada registro.
# - Onde a pessoa importa, a coluna vira autoria com nome explícito, opcional e com
#   ON DELETE SET NULL (excluir um usuário não apaga dado da empresa).
# - commercial_opportunities.user_id era só a cópia do criador do lote (conferido: 0
#   divergências) e é removida; accounts.legacy_user_id só servia ao backfill.
#
# Antes: backup em tmp/backups e busca no projeto sem uso restante dessas colunas.
class ReplaceUserTenancyWithAuthorship < ActiveRecord::Migration[8.1]
  AUTHORSHIP = {
    supplier_imports: :created_by_id,
    supplier_discovery_searches: :created_by_id,
    privacy_requests: :created_by_id,
    third_party_operators: :created_by_id,
    audit_reviews: :reviewed_by_id,
    privacy_audit_events: :performed_by_id
  }.freeze

  def up
    verify!

    remove_index :audit_reviews, name: "index_audit_reviews_on_lookup"
    remove_index :supplier_discovery_searches, name: "index_supplier_discovery_searches_on_user_id_and_search_id"
    remove_index :commercial_opportunities, name: "index_commercial_opportunities_on_user_id_and_status"
    remove_index :third_party_operators, name: "index_third_party_operators_on_user_id_and_active"

    AUTHORSHIP.each do |table, column|
      remove_foreign_key table, :users
      rename_column table, :user_id, column
      change_column_null table, column, true
      add_foreign_key table, :users, column: column, on_delete: :nullify
    end

    remove_foreign_key :commercial_opportunities, :users
    remove_column :commercial_opportunities, :user_id

    remove_index :accounts, name: "index_accounts_on_legacy_user_id"
    remove_column :accounts, :legacy_user_id

    add_index :third_party_operators, [ :account_id, :active ]
  end

  def down
    remove_index :third_party_operators, [ :account_id, :active ]
    add_column :accounts, :legacy_user_id, :bigint
    add_index :accounts, :legacy_user_id, unique: true, where: "legacy_user_id IS NOT NULL"

    add_reference :commercial_opportunities, :user, foreign_key: true
    execute "UPDATE commercial_opportunities co SET user_id = si.created_by_id FROM supplier_imports si WHERE si.id = co.supplier_import_id"

    AUTHORSHIP.each do |table, column|
      remove_foreign_key table, column: column
      rename_column table, column, :user_id
      add_foreign_key table, :users
    end

    add_index :commercial_opportunities, [ :user_id, :status ]
    add_index :supplier_discovery_searches, [ :user_id, :search_id ], unique: true
    add_index :audit_reviews, [ :user_id, :supplier_import_id, :record_external_id, :provider_call_id, :attempt_number ],
      unique: true, name: "index_audit_reviews_on_lookup"
    add_index :third_party_operators, [ :user_id, :active ]
  end

  private

  def verify!
    (AUTHORSHIP.keys + [ :commercial_opportunities ]).each do |table|
      missing = select_value("SELECT COUNT(*) FROM #{table} WHERE account_id IS NULL").to_i
      raise "#{table}: #{missing} registro(s) sem empresa; nada foi alterado." if missing.positive?
    end

    divergent = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM commercial_opportunities co JOIN supplier_imports si ON si.id = co.supplier_import_id
      WHERE co.user_id <> si.user_id
    SQL
    raise "commercial_opportunities: #{divergent} retorno(s) com autor diferente do lote; nada foi alterado." if divergent.positive?
  end
end
