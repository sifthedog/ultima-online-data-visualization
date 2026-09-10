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

ActiveRecord::Schema[8.1].define(version: 2026_09_10_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "consumed_materials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "graphic"
    t.integer "hue", default: 0, null: false
    t.string "name", null: false
    t.integer "quantity", null: false
    t.bigint "skill_attempt_id", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_attempt_id"], name: "index_consumed_materials_on_skill_attempt_id"
  end

  create_table "gathered_materials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "graphic"
    t.integer "hue", default: 0, null: false
    t.string "name", null: false
    t.integer "quantity", null: false
    t.bigint "skill_attempt_id", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_attempt_id"], name: "index_gathered_materials_on_skill_attempt_id"
  end

  create_table "skill_attempts", force: :cascade do |t|
    t.string "character_name"
    t.string "character_serial"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "outcome", null: false
    t.datetime "recorded_at", null: false
    t.datetime "run_started_at"
    t.integer "sequence"
    t.string "skill", null: false
    t.decimal "skill_from", precision: 4, scale: 1, null: false
    t.decimal "skill_to", precision: 4, scale: 1, null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["character_serial", "run_started_at"], name: "index_skill_attempts_on_character_serial_and_run_started_at"
    t.index ["external_id"], name: "index_skill_attempts_on_external_id", unique: true
    t.index ["recorded_at"], name: "index_skill_attempts_on_recorded_at"
    t.index ["skill", "skill_from"], name: "index_skill_attempts_on_skill_and_skill_from"
    t.index ["skill", "subject"], name: "index_skill_attempts_on_skill_and_subject"
  end

  add_foreign_key "consumed_materials", "skill_attempts"
  add_foreign_key "gathered_materials", "skill_attempts"
end
