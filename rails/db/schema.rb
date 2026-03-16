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

ActiveRecord::Schema[8.1].define(version: 2026_03_15_072804) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "sale_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "product_id"
    t.string "product_name", null: false
    t.integer "qty", null: false
    t.bigint "sale_id", null: false
    t.decimal "subtotal", precision: 15, scale: 2, null: false
    t.decimal "tax_amount", precision: 15, scale: 2, default: "0.0"
    t.string "tax_id"
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0"
    t.string "tax_setting"
    t.decimal "total", precision: 15, scale: 2, null: false
    t.string "unit"
    t.decimal "unit_price", precision: 15, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
  end

  create_table "sales", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "subtotal", precision: 15, scale: 2, null: false
    t.decimal "tax_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 15, scale: 2, null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "sale_items", "sales"
end
