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

ActiveRecord::Schema[8.2].define(version: 2026_09_04_000001) do
  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "custom_styles"
    t.string "join_code", null: false
    t.string "name", null: false
    t.json "settings"
    t.integer "singleton_guard", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_guard"], name: "index_accounts_on_singleton_guard", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agents", force: :cascade do |t|
    t.string "api_token"
    t.datetime "created_at", null: false
    t.datetime "last_active_at"
    t.string "mcp_session_id"
    t.string "model", null: false
    t.string "name", null: false
    t.string "program", null: false
    t.integer "project_id", null: false
    t.integer "status", default: 0, null: false
    t.text "task_description"
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_agents_on_api_token", unique: true
    t.index ["mcp_session_id"], name: "index_agents_on_mcp_session_id"
    t.index ["project_id", "name"], name: "index_agents_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_agents_on_project_id"
    t.index ["status"], name: "index_agents_on_status"
  end

  create_table "approval_request_actions", force: :cascade do |t|
    t.string "action"
    t.integer "actor_id"
    t.string "actor_type"
    t.integer "approval_request_id"
    t.datetime "created_at", null: false
    t.text "note"
    t.datetime "updated_at", null: false
  end

  create_table "approval_requests", force: :cascade do |t|
    t.integer "agent_id"
    t.datetime "created_at", null: false
    t.integer "message_id"
    t.json "payload"
    t.string "request_type"
    t.datetime "requested_at"
    t.datetime "resolved_at"
    t.integer "resolved_by_id"
    t.integer "room_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["requested_at"], name: "index_approval_requests_on_requested_at"
    t.index ["room_id", "status", "requested_at"], name: "index_approval_requests_on_room_id_and_status_and_requested_at"
    t.index ["room_id"], name: "index_approval_requests_on_room_id"
    t.index ["status"], name: "index_approval_requests_on_status"
  end

  create_table "attention_items", force: :cascade do |t|
    t.string "action_label"
    t.boolean "ai_confirm", default: false, null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.text "meta_text"
    t.boolean "overdue", default: false, null: false
    t.integer "project_id"
    t.datetime "resolved_at"
    t.integer "resolved_by_id"
    t.integer "room_id"
    t.integer "source_id"
    t.string "source_type"
    t.integer "status", default: 0, null: false
    t.integer "target_id"
    t.string "target_type"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["due_at"], name: "index_attention_items_on_due_at"
    t.index ["project_id", "status", "due_at"], name: "index_attention_items_on_project_id_and_status_and_due_at"
    t.index ["project_id"], name: "index_attention_items_on_project_id"
    t.index ["status"], name: "index_attention_items_on_status"
    t.index ["user_id", "status", "category"], name: "index_attention_items_on_user_id_and_status_and_category"
    t.index ["user_id"], name: "index_attention_items_on_user_id"
  end

  create_table "bans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["ip_address"], name: "index_bans_on_ip_address"
    t.index ["user_id"], name: "index_bans_on_user_id"
  end

  create_table "boosts", force: :cascade do |t|
    t.integer "booster_id", null: false
    t.string "content", limit: 16, null: false
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["booster_id"], name: "index_boosts_on_booster_id"
    t.index ["message_id"], name: "index_boosts_on_message_id"
  end

  create_table "company_status_items", force: :cascade do |t|
    t.json "actions", default: []
    t.string "category", null: false
    t.string "color"
    t.integer "company_status_period_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "detail_category"
    t.text "evidence"
    t.string "from_name"
    t.string "icon"
    t.text "impact"
    t.string "owner"
    t.integer "percent"
    t.integer "position", default: 0, null: false
    t.string "severity"
    t.string "status"
    t.text "subtitle"
    t.string "target_date"
    t.text "text"
    t.string "title"
    t.string "to_name"
    t.datetime "updated_at", null: false
    t.index ["company_status_period_id", "category"], name: "idx_on_company_status_period_id_category_c472881932"
    t.index ["company_status_period_id"], name: "index_company_status_items_on_company_status_period_id"
    t.index ["position"], name: "index_company_status_items_on_position"
  end

  create_table "company_status_periods", force: :cascade do |t|
    t.integer "account_id"
    t.datetime "created_at", null: false
    t.boolean "current", default: false, null: false
    t.date "ends_on"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.date "starts_on"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_company_status_periods_on_account_id"
    t.index ["current"], name: "index_company_status_periods_on_current"
    t.index ["position"], name: "index_company_status_periods_on_position"
    t.index ["slug"], name: "index_company_status_periods_on_slug", unique: true
  end

  create_table "file_reservations", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.boolean "exclusive", default: true, null: false
    t.datetime "expires_at", null: false
    t.json "patterns", default: [], null: false
    t.integer "project_id", null: false
    t.text "reason"
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_file_reservations_on_agent_id"
    t.index ["expires_at"], name: "index_file_reservations_on_expires_at"
    t.index ["project_id", "expires_at"], name: "index_file_reservations_on_project_id_and_expires_at"
    t.index ["project_id"], name: "index_file_reservations_on_project_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "connected_at"
    t.integer "connections", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "involvement", default: "mentions"
    t.datetime "last_read_at"
    t.integer "participant_id", null: false
    t.string "participant_type", null: false
    t.integer "room_id", null: false
    t.datetime "unread_at"
    t.datetime "updated_at", null: false
    t.index ["last_read_at"], name: "index_memberships_on_last_read_at"
    t.index ["participant_id"], name: "index_memberships_on_participant_id"
    t.index ["participant_type", "participant_id"], name: "index_memberships_on_participant_type_and_participant_id"
    t.index ["room_id", "created_at"], name: "index_memberships_on_room_id_and_created_at"
    t.index ["room_id", "participant_type", "participant_id"], name: "index_memberships_on_room_and_participant", unique: true
    t.index ["room_id"], name: "index_memberships_on_room_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "client_message_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "creator_id", null: false
    t.string "creator_type", null: false
    t.integer "room_id", null: false
    t.boolean "system", default: false, null: false
    t.string "system_type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["creator_type", "creator_id"], name: "index_messages_on_creator_type_and_creator_id"
    t.index ["room_id"], name: "index_messages_on_room_id"
  end

  create_table "output_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "event_data", default: {}, null: false
    t.integer "event_id"
    t.string "event_type", null: false
    t.string "group_id"
    t.boolean "synced", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_output_events_on_event_id"
    t.index ["event_type"], name: "index_output_events_on_event_type"
    t.index ["group_id"], name: "index_output_events_on_group_id"
    t.index ["synced", "created_at"], name: "index_output_events_on_synced_and_created_at"
  end

  create_table "project_adrs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.date "decision_date"
    t.string "file_path"
    t.string "identifier", null: false
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "status", default: "proposed", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_project_adrs_on_identifier"
    t.index ["position"], name: "index_project_adrs_on_position"
    t.index ["project_id"], name: "index_project_adrs_on_project_id"
  end

  create_table "project_all_hands_action_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "assignee_name"
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "due_date"
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_all_hands_action_items_on_position"
    t.index ["project_id"], name: "index_project_all_hands_action_items_on_project_id"
  end

  create_table "project_all_hands_decisions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "badge", default: "Logged in System"
    t.string "basis"
    t.datetime "created_at", null: false
    t.string "impact"
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_all_hands_decisions_on_position"
    t.index ["project_id"], name: "index_project_all_hands_decisions_on_project_id"
  end

  create_table "project_all_hands_takeaways", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_all_hands_takeaways_on_position"
    t.index ["project_id"], name: "index_project_all_hands_takeaways_on_project_id"
  end

  create_table "project_bottlenecks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.datetime "resolved_at"
    t.string "severity", default: "active"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_bottlenecks_on_position"
    t.index ["project_id"], name: "index_project_bottlenecks_on_project_id"
  end

  create_table "project_directory_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.string "file_path"
    t.string "item_type", default: "file", null: false
    t.string "name", null: false
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_project_directory_items_on_parent_id"
    t.index ["position"], name: "index_project_directory_items_on_position"
    t.index ["project_id"], name: "index_project_directory_items_on_project_id"
  end

  create_table "project_external_assets", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "doc_type"
    t.string "icon"
    t.string "meta_text"
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "source_type", default: "external_url", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["position"], name: "index_project_external_assets_on_position"
    t.index ["project_id"], name: "index_project_external_assets_on_project_id"
  end

  create_table "project_knowledge_activities", force: :cascade do |t|
    t.string "action_text", null: false
    t.boolean "active", default: true, null: false
    t.string "actor_color"
    t.string "actor_name", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "target_path"
    t.string "target_url"
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_knowledge_activities_on_position"
    t.index ["project_id"], name: "index_project_knowledge_activities_on_project_id"
  end

  create_table "project_knowledge_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "badge"
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_knowledge_items_on_position"
    t.index ["project_id"], name: "index_project_knowledge_items_on_project_id"
  end

  create_table "project_milestones", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon", default: "✅"
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_milestones_on_position"
    t.index ["project_id"], name: "index_project_milestones_on_project_id"
  end

  create_table "project_obsidian_notes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.string "html_source_path"
    t.string "html_source_type", default: "internal_file", null: false
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "tags"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_obsidian_notes_on_position"
    t.index ["project_id"], name: "index_project_obsidian_notes_on_project_id"
  end

  create_table "project_todos", force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "meta_text"
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_project_todos_on_position"
    t.index ["project_id"], name: "index_project_todos_on_project_id"
  end

  create_table "project_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["project_id", "user_id"], name: "index_project_users_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_users_on_project_id"
    t.index ["user_id"], name: "index_project_users_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.decimal "budget_spent", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "budget_total", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "current_phase", default: "Phase 1: Project Setup"
    t.text "description"
    t.string "name", null: false
    t.string "path", null: false
    t.boolean "private", default: false, null: false
    t.integer "progress_percent", default: 0
    t.text "recently_completed"
    t.text "roadmap"
    t.string "short_code"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["path"], name: "index_projects_on_path", unique: true
    t.index ["slug"], name: "index_projects_on_slug", unique: true
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key"
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.string "p256dh_key"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["endpoint", "p256dh_key", "auth_key"], name: "idx_on_endpoint_p256dh_key_auth_key_7553014576"
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "room_ai_activity_states", force: :cascade do |t|
    t.integer "agent_id"
    t.datetime "created_at", null: false
    t.integer "room_id"
    t.datetime "started_at"
    t.integer "state", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "agent_id"], name: "index_room_ai_activity_states_on_room_id_and_agent_id", unique: true
    t.index ["room_id"], name: "index_room_ai_activity_states_on_room_id"
    t.index ["updated_at"], name: "index_room_ai_activity_states_on_updated_at"
  end

  create_table "rooms", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.boolean "private", default: false, null: false
    t.integer "project_id"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["archived_at"], name: "index_rooms_on_archived_at"
    t.index ["parent_id"], name: "index_rooms_on_parent_id"
    t.index ["project_id", "type"], name: "index_rooms_on_project_id_and_type"
    t.index ["project_id"], name: "index_rooms_on_project_id"
  end

  create_table "searches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "query", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_searches_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "bio"
    t.string "bot_token"
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.string "email_address"
    t.string "job_title"
    t.string "name", null: false
    t.string "password_digest"
    t.json "preferences"
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["bot_token"], name: "index_users_on_bot_token", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_webhooks_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agents", "projects"
  add_foreign_key "approval_request_actions", "approval_requests"
  add_foreign_key "approval_requests", "agents"
  add_foreign_key "approval_requests", "messages"
  add_foreign_key "approval_requests", "rooms"
  add_foreign_key "approval_requests", "users", column: "resolved_by_id"
  add_foreign_key "attention_items", "projects"
  add_foreign_key "attention_items", "rooms"
  add_foreign_key "attention_items", "users"
  add_foreign_key "attention_items", "users", column: "resolved_by_id"
  add_foreign_key "bans", "users"
  add_foreign_key "boosts", "messages"
  add_foreign_key "company_status_items", "company_status_periods"
  add_foreign_key "company_status_periods", "accounts"
  add_foreign_key "file_reservations", "agents"
  add_foreign_key "file_reservations", "projects"
  add_foreign_key "messages", "rooms"
  add_foreign_key "project_adrs", "projects"
  add_foreign_key "project_all_hands_action_items", "projects"
  add_foreign_key "project_all_hands_decisions", "projects"
  add_foreign_key "project_all_hands_takeaways", "projects"
  add_foreign_key "project_bottlenecks", "projects"
  add_foreign_key "project_directory_items", "project_directory_items", column: "parent_id"
  add_foreign_key "project_directory_items", "projects"
  add_foreign_key "project_external_assets", "projects"
  add_foreign_key "project_knowledge_activities", "projects"
  add_foreign_key "project_knowledge_items", "projects"
  add_foreign_key "project_milestones", "projects"
  add_foreign_key "project_obsidian_notes", "projects"
  add_foreign_key "project_todos", "projects"
  add_foreign_key "project_users", "projects"
  add_foreign_key "project_users", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "room_ai_activity_states", "agents"
  add_foreign_key "room_ai_activity_states", "rooms"
  add_foreign_key "rooms", "projects"
  add_foreign_key "rooms", "rooms", column: "parent_id"
  add_foreign_key "searches", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "webhooks", "users"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "message_search_index", "fts5", ["body", "tokenize=porter"]
end
