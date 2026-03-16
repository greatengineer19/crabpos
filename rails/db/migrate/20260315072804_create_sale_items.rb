class CreateSaleItems < ActiveRecord::Migration[8.1]
  def change
    create_table :sale_items do |t|
      t.references :sale,         null: false, foreign_key: true
      t.integer    :product_id
      t.string     :product_name, null: false
      t.integer    :qty,          null: false
      t.string     :unit
      t.decimal    :unit_price,   precision: 15, scale: 2, null: false
      t.string     :tax_setting
      t.decimal    :tax_rate,     precision: 5,  scale: 2, default: 0
      t.string     :tax_id
      t.decimal    :tax_amount,   precision: 15, scale: 2, default: 0
      t.decimal    :subtotal,     precision: 15, scale: 2, null: false
      t.decimal    :total,        precision: 15, scale: 2, null: false
 
      t.timestamps
    end
  end
end
