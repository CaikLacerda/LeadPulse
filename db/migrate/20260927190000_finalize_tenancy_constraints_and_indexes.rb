# Fase 14 do tenancy final: índices e restrições coerentes com a empresa como dona.
#
# - Índices que vieram do antigo user_id (hoje colunas de autoria) viram índices por
#   empresa, que é como as telas consultam (LGPD: pedidos e trilha).
# - Sai o índice simples de account_id onde um índice composto já começa por account_id.
# - Check constraints repetem no banco os valores que os models já validam.
class FinalizeTenancyConstraintsAndIndexes < ActiveRecord::Migration[8.1]
  LOCAL_STATUSES = "'pendente', 'processando', 'concluido', 'erro'".freeze

  def change
    add_index :privacy_requests, [ :account_id, :created_at ]
    add_index :privacy_requests, [ :account_id, :status ]
    remove_index :privacy_requests, [ :created_by_id, :status ]
    remove_index :privacy_requests, :account_id

    add_index :privacy_audit_events, [ :account_id, :occurred_at ]
    add_index :privacy_audit_events, [ :account_id, :action ]
    remove_index :privacy_audit_events, [ :performed_by_id, :action ]
    remove_index :privacy_audit_events, [ :performed_by_id, :occurred_at ]
    remove_index :privacy_audit_events, :account_id

    remove_index :account_memberships, :account_id
    remove_index :analytics_api_tokens, :account_id
    remove_index :supplier_imports, :account_id
    remove_index :commercial_opportunities, :account_id
    remove_index :commercial_opportunities, :supplier_import_id
    remove_index :supplier_discovery_searches, :account_id
    remove_index :audit_reviews, :account_id
    remove_index :third_party_operators, :account_id

    add_check_constraint :supplier_imports, "status IS NULL OR status IN (#{LOCAL_STATUSES})", name: "supplier_imports_status_check"
    add_check_constraint :supplier_imports, "workflow_kind IN ('cadastral_validation', 'supplier_validation')", name: "supplier_imports_workflow_kind_check"
    add_check_constraint :supplier_imports, "source IN ('integracao_externa', 'supplier_discovery')", name: "supplier_imports_source_check"
    add_check_constraint :commercial_opportunities, "status IN (#{LOCAL_STATUSES})", name: "commercial_opportunities_status_check"
    add_check_constraint :supplier_discovery_searches, "status IN (#{LOCAL_STATUSES})", name: "supplier_discovery_searches_status_check"
    add_check_constraint :privacy_requests, "status IN ('open', 'in_progress', 'resolved', 'rejected')", name: "privacy_requests_status_check"
    add_check_constraint :analytics_api_tokens, "token_prefix LIKE 'lpbi\\_%'", name: "analytics_api_tokens_prefix_check"
  end
end
