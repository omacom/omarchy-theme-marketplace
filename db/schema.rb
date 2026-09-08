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

ActiveRecord::Schema[8.1].define(version: 2026_09_08_080100) do
  create_table "command_copies", force: :cascade do |t|
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "day", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug", "day"], name: "index_command_copies_on_slug_and_day", unique: true
  end

  create_table "likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["slug"], name: "index_likes_on_slug"
    t.index ["user_id", "slug"], name: "index_likes_on_user_id_and_slug", unique: true
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.bigint "github_id", null: false
    t.string "login", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
    t.index ["login"], name: "index_users_on_login"
  end

  add_foreign_key "likes", "users"
  add_foreign_key "sessions", "users"
end
