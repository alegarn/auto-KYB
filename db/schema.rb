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

ActiveRecord::Schema[8.1].define(version: 2026_02_11_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "client_forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_token"
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.uuid "form_id", null: false
    t.string "password_digest"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.datetime "validated_at"
    t.index ["access_token"], name: "index_client_forms_on_access_token", unique: true
    t.index ["client_id"], name: "index_client_forms_on_client_id"
    t.index ["form_id"], name: "index_client_forms_on_form_id"
  end

  create_table "clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "address"
    t.string "company_id"
    t.string "company_name", null: false
    t.string "country"
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "form_status", default: 0, null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((company_name)::text)", name: "index_clients_on_user_id_and_lower_company_name"
    t.index "user_id, lower((name)::text)", name: "index_clients_on_user_id_and_lower_name"
    t.index ["company_id"], name: "index_clients_on_company_id"
    t.index ["country"], name: "index_clients_on_country"
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "form_fields", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field_type", null: false
    t.uuid "form_id", null: false
    t.string "label", null: false
    t.jsonb "metadata", default: {}
    t.integer "position"
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["form_id", "position"], name: "index_form_fields_on_form_id_and_position"
    t.index ["form_id"], name: "index_form_fields_on_form_id"
  end

  create_table "form_responses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_form_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["client_form_id", "version"], name: "index_form_responses_on_client_form_id_and_version", unique: true
    t.index ["client_form_id"], name: "index_form_responses_on_client_form_id"
  end

  create_table "forms", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.jsonb "structure", default: {}
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_forms_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_forms_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["ip_address"], name: "index_sessions_on_ip_address"
    t.index ["user_agent"], name: "index_sessions_on_user_agent"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "client_forms", "clients"
  add_foreign_key "client_forms", "forms"
  add_foreign_key "clients", "users"
  add_foreign_key "form_fields", "forms"
  add_foreign_key "form_responses", "client_forms"
  add_foreign_key "forms", "users"
  add_foreign_key "sessions", "users"
end
