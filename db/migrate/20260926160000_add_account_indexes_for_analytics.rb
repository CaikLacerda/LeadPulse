# Índices por conta para o Analytics (filtros por período) e para as listagens que hoje
# ordenam e filtram por conta. Só adiciona índices; os antigos por user_id continuam até a
# etapa E ser aprovada. CONCURRENTLY para não bloquear escrita nas tabelas em produção.
class AddAccountIndexesForAnalytics < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :supplier_imports, [ :account_id, :created_at ], algorithm: :concurrently, if_not_exists: true
    add_index :supplier_imports, [ :account_id, :validation_started_at ], algorithm: :concurrently, if_not_exists: true
    add_index :commercial_opportunities, [ :account_id, :created_at ], algorithm: :concurrently, if_not_exists: true
    add_index :commercial_opportunities, [ :account_id, :status ], algorithm: :concurrently, if_not_exists: true
    add_index :supplier_discovery_searches, [ :account_id, :created_at ], algorithm: :concurrently, if_not_exists: true
    add_index :supplier_discovery_searches, [ :account_id, :search_id ], unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
