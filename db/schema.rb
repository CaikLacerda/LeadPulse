# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_16_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "accepted_by_id"
    t.bigint "account_id", null: false
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id"
    t.string "role", null: false
    t.datetime "sent_at", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index "account_id, lower((email)::text)", name: "index_account_invitations_open_email", unique: true, where: "((accepted_at IS NULL) AND (canceled_at IS NULL))"
    t.index ["accepted_by_id"], name: "index_account_invitations_on_accepted_by_id"
    t.index ["account_id"], name: "index_account_invitations_on_account_id"
    t.index ["invited_by_id"], name: "index_account_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_account_invitations_on_token_digest", unique: true
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'manager'::character varying, 'operator'::character varying, 'auditor'::character varying, 'viewer'::character varying]::text[])", name: "account_invitations_role_check"
  end

  create_table "account_memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.bigint "invited_by_id"
    t.string "role", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id", "status"], name: "index_account_memberships_on_account_id_and_status"
    t.index ["account_id", "user_id"], name: "index_account_memberships_on_account_id_and_user_id", unique: true
    t.index ["invited_by_id"], name: "index_account_memberships_on_invited_by_id"
    t.index ["user_id"], name: "index_account_memberships_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'manager'::character varying, 'operator'::character varying, 'auditor'::character varying, 'viewer'::character varying]::text[])", name: "account_memberships_role_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'disabled'::character varying]::text[])", name: "account_memberships_status_check"
  end

  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "lgpd_controller_email"
    t.string "lgpd_controller_name"
    t.integer "lgpd_evidence_retention_days", default: 180, null: false
    t.string "lgpd_legal_basis", default: "legitimate_interest", null: false
    t.text "lgpd_notice_script"
    t.string "lgpd_purpose", default: "qualificacao_de_fornecedores_por_chamada_automatizada", null: false
    t.boolean "lgpd_recording_allowed", default: true, null: false
    t.boolean "lgpd_stop_automatic_calls_on_refusal", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "validation_account_id"
    t.jsonb "validation_account_response", default: {}, null: false
    t.text "validation_api_token"
    t.datetime "validation_api_token_created_at"
    t.string "validation_api_token_prefix"
    t.text "validation_calling_profile"
    t.string "validation_company_name"
    t.string "validation_external_account_id"
    t.string "validation_openai_realtime_model", default: "gpt-realtime-2.1-mini", null: false
    t.decimal "validation_openai_realtime_output_speed", precision: 4, scale: 2
    t.string "validation_openai_realtime_voice", default: "cedar", null: false
    t.text "validation_openai_style_instructions"
    t.string "validation_owner_email"
    t.string "validation_owner_name"
    t.string "validation_spoken_company_name"
    t.string "validation_twilio_account_sid"
    t.jsonb "validation_twilio_phone_numbers", default: [], null: false
    t.string "validation_twilio_webhook_base_url"
    t.index ["validation_account_id"], name: "index_accounts_on_validation_account_id", unique: true, where: "(validation_account_id IS NOT NULL)"
    t.index ["validation_external_account_id"], name: "index_accounts_on_validation_external_account_id", unique: true, where: "(validation_external_account_id IS NOT NULL)"
  end

  create_table "analytics_api_tokens", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.datetime "revoked_at"
    t.bigint "revoked_by_id"
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "revoked_at"], name: "index_analytics_api_tokens_on_account_id_and_revoked_at"
    t.index ["created_by_id"], name: "index_analytics_api_tokens_on_created_by_id"
    t.index ["revoked_by_id"], name: "index_analytics_api_tokens_on_revoked_by_id"
    t.index ["token_digest"], name: "index_analytics_api_tokens_on_token_digest", unique: true
    t.check_constraint "token_prefix::text ~~ 'lpbi\\_%'::text", name: "analytics_api_tokens_prefix_check"
  end

  create_table "audit_reviews", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "attempt_number"
    t.datetime "created_at", null: false
    t.string "original_result"
    t.string "provider_call_id"
    t.string "record_external_id"
    t.text "review_note"
    t.datetime "reviewed_at", null: false
    t.bigint "reviewed_by_id"
    t.string "reviewed_result", null: false
    t.bigint "supplier_import_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "supplier_import_id", "record_external_id", "provider_call_id", "attempt_number"], name: "index_audit_reviews_on_account_lookup", unique: true
    t.index ["reviewed_by_id"], name: "index_audit_reviews_on_reviewed_by_id"
    t.index ["supplier_import_id"], name: "index_audit_reviews_on_supplier_import_id"
  end

  create_table "commercial_opportunities", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "callback_phone", null: false
    t.string "callback_phone_choice"
    t.datetime "callback_preferred_at"
    t.text "callback_preferred_time"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "finished_at"
    t.datetime "last_synced_at"
    t.text "lot_price_ranges"
    t.text "minimum_order"
    t.string "normalization_source"
    t.text "normalized_lot_price_ranges"
    t.text "normalized_minimum_order"
    t.text "normalized_product_specification"
    t.text "normalized_unit_price"
    t.string "outcome"
    t.text "product_specification"
    t.string "remote_batch_id"
    t.string "remote_batch_status"
    t.jsonb "request_payload", default: {}, null: false
    t.jsonb "response_payload", default: {}, null: false
    t.boolean "result_ready", default: false, null: false
    t.string "segment_name"
    t.string "source_external_id", null: false
    t.string "source_phone"
    t.datetime "started_at"
    t.string "status", default: "pendente", null: false
    t.bigint "supplier_import_id", null: false
    t.string "supplier_name", null: false
    t.text "unit_price"
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_commercial_opportunities_on_account_id_and_created_at"
    t.index ["account_id", "status"], name: "index_commercial_opportunities_on_account_id_and_status"
    t.index ["remote_batch_id"], name: "index_commercial_opportunities_on_remote_batch_id"
    t.index ["supplier_import_id", "source_external_id"], name: "index_commercial_opportunities_on_source_record", unique: true
    t.check_constraint "status::text = ANY (ARRAY['pendente'::character varying, 'processando'::character varying, 'concluido'::character varying, 'erro'::character varying]::text[])", name: "commercial_opportunities_status_check"
  end

  create_table "mobile_sessions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "password_fingerprint", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id"], name: "index_mobile_sessions_on_account_id"
    t.index ["token_digest"], name: "index_mobile_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_mobile_sessions_on_user_id"
  end

  create_table "plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "supplier_limit", default: 10, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.integer "usage", default: 0, null: false
    t.decimal "value", default: "0.0", null: false
  end

  create_table "privacy_audit_events", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.bigint "performed_by_id"
    t.string "resource_id"
    t.string "resource_type"
    t.bigint "supplier_import_id"
    t.datetime "updated_at", null: false
    t.index ["account_id", "action"], name: "index_privacy_audit_events_on_account_id_and_action"
    t.index ["account_id", "occurred_at"], name: "index_privacy_audit_events_on_account_id_and_occurred_at"
    t.index ["performed_by_id"], name: "index_privacy_audit_events_on_performed_by_id"
    t.index ["supplier_import_id"], name: "index_privacy_audit_events_on_supplier_import_id"
  end

  create_table "privacy_requests", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "description"
    t.string "phone"
    t.string "request_type", null: false
    t.datetime "requested_at", null: false
    t.text "resolution"
    t.datetime "resolved_at"
    t.string "status", default: "open", null: false
    t.string "subject_contact"
    t.string "subject_name"
    t.bigint "supplier_import_id"
    t.string "supplier_name"
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_privacy_requests_on_account_id_and_created_at"
    t.index ["account_id", "status"], name: "index_privacy_requests_on_account_id_and_status"
    t.index ["created_by_id"], name: "index_privacy_requests_on_created_by_id"
    t.index ["supplier_import_id"], name: "index_privacy_requests_on_supplier_import_id"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'in_progress'::character varying, 'resolved'::character varying, 'rejected'::character varying]::text[])", name: "privacy_requests_status_check"
  end

  create_table "simulations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.float "accuracy"
    t.string "call_result", limit: 40
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.integer "duration_ms"
    t.datetime "finished_at"
    t.string "mode", limit: 24, null: false
    t.float "raw_value_accuracy"
    t.string "remote_id", limit: 120, null: false
    t.string "scenario_key", limit: 40, null: false
    t.string "status", limit: 24, default: "queued", null: false
    t.string "target_type", limit: 40, default: "system_workflow", null: false
    t.integer "turn_count"
    t.datetime "updated_at", null: false
    t.string "workflow_key", limit: 80, null: false
    t.index ["account_id", "created_at"], name: "index_simulations_on_account_id_and_created_at"
    t.index ["account_id", "remote_id"], name: "index_simulations_on_account_id_and_remote_id", unique: true
    t.index ["account_id"], name: "index_simulations_on_account_id"
    t.index ["created_by_id"], name: "index_simulations_on_created_by_id"
  end

  create_table "supplier_discovery_searches", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "callback_contact_name"
    t.string "callback_phone"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "error_message"
    t.datetime "generated_at"
    t.string "mode"
    t.string "region"
    t.jsonb "request_payload", default: {}, null: false
    t.jsonb "response_payload", default: {}, null: false
    t.string "results_filename"
    t.binary "results_xlsx_data"
    t.string "search_id", null: false
    t.string "segment_name", null: false
    t.string "status", default: "concluido", null: false
    t.integer "total_suppliers", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_supplier_discovery_searches_on_account_id_and_created_at"
    t.index ["account_id", "search_id"], name: "index_supplier_discovery_searches_on_account_id_and_search_id", unique: true
    t.index ["created_by_id"], name: "index_supplier_discovery_searches_on_created_by_id"
    t.check_constraint "status::text = ANY (ARRAY['pendente'::character varying, 'processando'::character varying, 'concluido'::character varying, 'erro'::character varying]::text[])", name: "supplier_discovery_searches_status_check"
  end

  create_table "supplier_import_versions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event"
    t.string "event_type"
    t.integer "size"
    t.bigint "supplier_import_id", null: false
    t.datetime "updated_at", null: false
    t.index ["supplier_import_id"], name: "index_supplier_import_versions_on_supplier_import_id"
  end

  create_table "supplier_imports", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "error_message"
    t.string "file_name"
    t.datetime "finished_at"
    t.jsonb "import_metadata", default: {}, null: false
    t.integer "invalid_rows", default: 0, null: false
    t.binary "invalid_xlsx_data"
    t.datetime "last_synced_at"
    t.string "remote_batch_id"
    t.string "remote_batch_status"
    t.jsonb "request_payload", default: {}, null: false
    t.jsonb "response_payload", default: {}, null: false
    t.boolean "result_ready", default: false, null: false
    t.string "source", default: "integracao_externa", null: false
    t.string "status"
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "valid_rows", default: 0, null: false
    t.binary "valid_xlsx_data"
    t.datetime "validation_started_at"
    t.string "workflow_kind", default: "cadastral_validation", null: false
    t.binary "xlsx_data"
    t.index ["account_id", "created_at"], name: "index_supplier_imports_on_account_id_and_created_at"
    t.index ["account_id", "validation_started_at"], name: "index_supplier_imports_on_account_id_and_validation_started_at"
    t.index ["created_by_id"], name: "index_supplier_imports_on_created_by_id"
    t.index ["remote_batch_id"], name: "index_supplier_imports_on_remote_batch_id"
    t.check_constraint "source::text = ANY (ARRAY['integracao_externa'::character varying, 'supplier_discovery'::character varying]::text[])", name: "supplier_imports_source_check"
    t.check_constraint "status IS NULL OR (status::text = ANY (ARRAY['pendente'::character varying, 'processando'::character varying, 'concluido'::character varying, 'erro'::character varying]::text[]))", name: "supplier_imports_status_check"
    t.check_constraint "workflow_kind::text = ANY (ARRAY['cadastral_validation'::character varying, 'supplier_validation'::character varying]::text[])", name: "supplier_imports_workflow_kind_check"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "company_name", null: false
    t.datetime "created_at", null: false
    t.string "document"
    t.string "name", null: false
    t.string "normalized_phone"
    t.string "phone_raw"
    t.string "phone_source"
    t.string "phone_status"
    t.bigint "supplier_import_id"
    t.datetime "updated_at", null: false
    t.index ["document"], name: "index_suppliers_on_document"
    t.index ["normalized_phone"], name: "index_suppliers_on_normalized_phone"
    t.index ["supplier_import_id"], name: "index_suppliers_on_supplier_import_id"
  end

  create_table "third_party_operators", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "active", default: true, null: false
    t.string "contract_reference"
    t.string "country"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "data_shared"
    t.string "name", null: false
    t.text "purpose"
    t.string "service_type", null: false
    t.string "technical_owner"
    t.datetime "updated_at", null: false
    t.index ["account_id", "active"], name: "index_third_party_operators_on_account_id_and_active"
    t.index ["created_by_id"], name: "index_third_party_operators_on_created_by_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspace_notification_reads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "notification_key", limit: 120, null: false
    t.datetime "read_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "notification_key"], name: "idx_on_user_id_notification_key_573a03c093", unique: true
    t.index ["user_id"], name: "index_workspace_notification_reads_on_user_id"
  end

  add_foreign_key "account_invitations", "accounts"
  add_foreign_key "account_invitations", "users", column: "accepted_by_id", on_delete: :nullify
  add_foreign_key "account_invitations", "users", column: "invited_by_id", on_delete: :nullify
  add_foreign_key "account_memberships", "accounts"
  add_foreign_key "account_memberships", "users"
  add_foreign_key "account_memberships", "users", column: "invited_by_id", on_delete: :nullify
  add_foreign_key "analytics_api_tokens", "accounts"
  add_foreign_key "analytics_api_tokens", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "analytics_api_tokens", "users", column: "revoked_by_id", on_delete: :nullify
  add_foreign_key "audit_reviews", "accounts"
  add_foreign_key "audit_reviews", "supplier_imports"
  add_foreign_key "audit_reviews", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "commercial_opportunities", "accounts"
  add_foreign_key "commercial_opportunities", "supplier_imports"
  add_foreign_key "mobile_sessions", "accounts", on_delete: :cascade
  add_foreign_key "mobile_sessions", "users", on_delete: :cascade
  add_foreign_key "privacy_audit_events", "accounts"
  add_foreign_key "privacy_audit_events", "supplier_imports", on_delete: :nullify
  add_foreign_key "privacy_audit_events", "users", column: "performed_by_id", on_delete: :nullify
  add_foreign_key "privacy_requests", "accounts"
  add_foreign_key "privacy_requests", "supplier_imports", on_delete: :nullify
  add_foreign_key "privacy_requests", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "simulations", "accounts"
  add_foreign_key "simulations", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "supplier_discovery_searches", "accounts"
  add_foreign_key "supplier_discovery_searches", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "supplier_import_versions", "supplier_imports"
  add_foreign_key "supplier_imports", "accounts"
  add_foreign_key "supplier_imports", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "suppliers", "supplier_imports"
  add_foreign_key "third_party_operators", "accounts"
  add_foreign_key "third_party_operators", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "workspace_notification_reads", "users"
end
