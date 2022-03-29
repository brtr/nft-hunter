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

ActiveRecord::Schema.define(version: 2022_03_29_052724) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "nft_histories", force: :cascade do |t|
    t.integer "nft_id"
    t.integer "sales"
    t.decimal "floor_price"
    t.decimal "volume"
    t.date "event_date"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.decimal "floor_price_7d"
    t.index ["nft_id"], name: "index_nft_histories_on_nft_id"
  end

  create_table "nfts", force: :cascade do |t|
    t.integer "chain_id"
    t.string "name"
    t.string "symbol"
    t.string "slug"
    t.string "website"
    t.string "opensea_url"
    t.string "address"
    t.string "logo"
    t.decimal "total_supply"
    t.decimal "floor_cap"
    t.decimal "listed_ratio"
    t.decimal "variation"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "owner_nfts", force: :cascade do |t|
    t.integer "owner_id"
    t.integer "nft_id"
    t.integer "amount"
    t.string "token_ids"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["owner_id", "nft_id"], name: "index_owner_nfts_on_owner_id_and_nft_id"
  end

  create_table "owners", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

end
