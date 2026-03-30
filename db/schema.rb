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

ActiveRecord::Schema[8.1].define(version: 2026_04_01_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "supplier_limit", default: 10, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.integer "usage", default: 0, null: false
    t.decimal "value", default: "0.0", null: false
  end

  create_table "supplier_discovery_searches", force: :cascade do |t|
    t.string "callback_contact_name"
    t.string "callback_phone"
    t.datetime "created_at", null: false
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
    t.bigint "user_id", null: false
    t.index ["user_id", "search_id"], name: "index_supplier_discovery_searches_on_user_id_and_search_id", unique: true
    t.index ["user_id"], name: "index_supplier_discovery_searches_on_user_id"
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
    t.datetime "created_at", null: false
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
    t.bigint "user_id", null: false
    t.integer "valid_rows", default: 0, null: false
    t.binary "valid_xlsx_data"
    t.datetime "validation_started_at"
    t.string "workflow_kind", default: "cadastral_validation", null: false
    t.binary "xlsx_data"
    t.index ["remote_batch_id"], name: "index_supplier_imports_on_remote_batch_id"
    t.index ["user_id"], name: "index_supplier_imports_on_user_id"
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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.bigint "validation_account_id"
    t.jsonb "validation_account_response", default: {}, null: false
    t.text "validation_api_token"
    t.datetime "validation_api_token_created_at"
    t.string "validation_api_token_prefix"
    t.string "validation_company_name"
    t.string "validation_external_account_id"
    t.text "validation_openai_api_key"
    t.string "validation_openai_realtime_model", default: "gpt-realtime-1.5", null: false
    t.decimal "validation_openai_realtime_output_speed", precision: 4, scale: 2
    t.string "validation_openai_realtime_voice", default: "cedar", null: false
    t.text "validation_openai_style_instructions"
    t.string "validation_owner_email"
    t.string "validation_owner_name"
    t.string "validation_spoken_company_name"
    t.string "validation_twilio_account_sid"
    t.text "validation_twilio_auth_token"
    t.jsonb "validation_twilio_phone_numbers", default: [], null: false
    t.string "validation_twilio_webhook_base_url"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "supplier_discovery_searches", "users"
  add_foreign_key "supplier_import_versions", "supplier_imports"
  add_foreign_key "supplier_imports", "users"
  add_foreign_key "suppliers", "supplier_imports"
end
