class SaleItem < ApplicationRecord
  belongs_to :sale

  validates :product_name, :qty, :unit_price, :total, presence: true
  validates :qty, numericality: { greater_than: 0 }
end