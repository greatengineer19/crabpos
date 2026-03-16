module Api
  module V1
    class TransactionsController < ApplicationController
      def create
        sale = Sale.new(
          subtotal: sale_params[:subtotal],
          tax_amount: sale_params[:tax_amount],
          total: sale_params[:total]
        )

        if sale.save
          sale_params[:items].each do |item|
            sale.sale_items.create!(
              product_id: item[:product_id],
              product_name: item[:product_name],
              qty: item[:qty],
              unit: item[:unit],
              unit_price: item[:unit_price],
              tax_setting: item[:tax_setting],
              tax_rate: item[:tax_rate],
              tax_id: item[:tax_id],
              tax_amount: item[:tax_amount],
              subtotal: item[:subtotal],
              total: item[:total]
            )
          end

          render json: {
            transaction_id: sale.id,
            message: 'Transaction saved successfully'
          }, status: :created

        else
          render json: { errors: sale.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      private

      def sale_params
        params.require(:transaction).permit(
          :subtotal, :tax_amount, :total,
          items: [
            :product_id, :product_name, :qty, :unit,
            :unit_price, :tax_setting, :tax_rate, :tax_id,
            :tax_amount, :subtotal, :total
          ]
        )
      end
    end
  end
end