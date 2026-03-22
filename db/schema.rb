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

ActiveRecord::Schema[8.1].define(version: 2026_03_23_000000) do
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

  create_table "backup_records", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "size_bytes"
    t.datetime "started_at"
    t.string "status", null: false
    t.string "storage_path"
    t.string "storage_type", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at"], name: "index_backup_records_on_started_at"
    t.index ["status"], name: "index_backup_records_on_status"
  end

  create_table "blocks", force: :cascade do |t|
    t.string "block_type", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index ["document_id", "position"], name: "index_blocks_on_document_id_and_position"
    t.index ["document_id"], name: "index_blocks_on_document_id"
  end

  create_table "calendar_event_tags", force: :cascade do |t|
    t.integer "calendar_event_id", null: false
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_event_id", "tag_id"], name: "index_calendar_event_tags_on_calendar_event_id_and_tag_id", unique: true
    t.index ["calendar_event_id"], name: "index_calendar_event_tags_on_calendar_event_id"
    t.index ["tag_id"], name: "index_calendar_event_tags_on_tag_id"
  end

  create_table "calendar_events", force: :cascade do |t|
    t.boolean "all_day", default: false, null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at"
    t.string "google_calendar_id", default: "primary", null: false
    t.string "google_event_id"
    t.string "html_link"
    t.datetime "reminded_at"
    t.string "source", default: "google", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "confirmed", null: false
    t.datetime "synced_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["google_event_id"], name: "index_calendar_events_on_google_event_id", unique: true
    t.index ["source"], name: "index_calendar_events_on_source"
    t.index ["starts_at"], name: "index_calendar_events_on_starts_at"
    t.index ["status", "starts_at"], name: "index_calendar_events_on_status_and_starts_at"
    t.index ["status"], name: "index_calendar_events_on_status"
  end

  create_table "document_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "source_document_id", null: false
    t.integer "target_document_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_document_id", "target_document_id"], name: "idx_on_source_document_id_target_document_id_ecc1a1ec96", unique: true
    t.index ["target_document_id"], name: "index_document_links_on_target_document_id"
  end

  create_table "document_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "document_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_tags_on_document_id"
    t.index ["tag_id"], name: "index_document_tags_on_tag_id"
  end

  create_table "documents", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "document_type", default: "note", null: false
    t.boolean "pinned", default: false, null: false
    t.string "slug"
    t.string "source"
    t.string "status", default: "inbox", null: false
    t.integer "telegram_chat_id", limit: 8
    t.integer "telegram_message_id", limit: 8
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["document_type"], name: "index_documents_on_document_type"
    t.index ["pinned"], name: "index_documents_on_pinned"
    t.index ["slug"], name: "index_documents_on_slug", unique: true
    t.index ["source"], name: "index_documents_on_source"
    t.index ["status"], name: "index_documents_on_status"
    t.index ["telegram_chat_id", "telegram_message_id"], name: "index_documents_on_telegram_chat_id_and_telegram_message_id"
  end

  create_table "storage_migrations", force: :cascade do |t|
    t.datetime "completed_at"
    t.integer "completed_items", default: 0
    t.datetime "created_at", null: false
    t.text "error_log"
    t.integer "failed_items", default: 0
    t.string "from_provider", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.string "to_provider", null: false
    t.integer "total_items", default: 0
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_storage_migrations_on_status"
  end

  create_table "storage_settings", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "config_encrypted"
    t.datetime "created_at", null: false
    t.datetime "last_checked_at"
    t.string "provider", default: "local", null: false
    t.string "status", default: "unchecked"
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name"
  end

  create_table "task_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.integer "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_task_tags_on_tag_id"
    t.index ["task_id", "tag_id"], name: "index_task_tags_on_task_id_and_tag_id", unique: true
    t.index ["task_id"], name: "index_task_tags_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "document_id"
    t.date "due_date"
    t.time "due_time"
    t.integer "position", default: 0, null: false
    t.string "priority", default: "mid", null: false
    t.string "recurrence_rule"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["completed", "due_date"], name: "index_tasks_on_completed_and_due_date"
    t.index ["completed", "priority", "position"], name: "index_tasks_on_completed_and_priority_and_position"
    t.index ["document_id"], name: "index_tasks_on_document_id"
    t.index ["due_date"], name: "index_tasks_on_due_date"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "blocks", "documents"
  add_foreign_key "calendar_event_tags", "calendar_events"
  add_foreign_key "calendar_event_tags", "tags"
  add_foreign_key "document_links", "documents", column: "source_document_id"
  add_foreign_key "document_links", "documents", column: "target_document_id"
  add_foreign_key "document_tags", "documents"
  add_foreign_key "document_tags", "tags"
  add_foreign_key "task_tags", "tags"
  add_foreign_key "task_tags", "tasks"
  add_foreign_key "tasks", "documents"
end
