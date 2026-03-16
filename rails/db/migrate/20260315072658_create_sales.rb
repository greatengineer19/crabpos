class CreateSales < ActiveRecord::Migration[8.1]
  def change
    create_table :sales do |t|
      t.decimal :subtotal,   precision: 15, scale: 2, null: false
      t.decimal :tax_amount, precision: 15, scale: 2, null: false, default: 0
      t.decimal :total,      precision: 15, scale: 2, null: false
 
      t.timestamps
    end
  end
end
