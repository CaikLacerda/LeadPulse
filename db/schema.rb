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

ActiveRecord::Schema[8.1].define(version: 2026_03_25_135824) do
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
    t.integer "invalid_rows", default: 0, null: false
    t.binary "invalid_xlsx_data"
    t.string "status"
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "valid_rows", default: 0, null: false
    t.binary "valid_xlsx_data"
    t.binary "xlsx_data"
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "supplier_import_versions", "supplier_imports"
  add_foreign_key "supplier_imports", "users"
  add_foreign_key "suppliers", "supplier_imports"
end
