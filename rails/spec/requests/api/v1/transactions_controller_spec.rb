require 'rails_helper'

RSpec.describe Api::V1::TransactionsController, type: :request do
  let(:valid_payload) do
    {
      transaction: {
        subtotal: 63000,
        tax_amount: 6937,
        total: 70000,
        items: [
          {
            product_id: 1,
            product_name: 'Nasi Goreng Spesial',
            qty: 2,
            unit: 'pcs',
            unit_price: 35000,
            tax_setting: 'tax_inclusive',
            tax_rate: 11,
            tax_id: 'indonesia_pb11%.id',
            tax_amount: 6937,
            subtotal: 63063,
            total: 70000
          }
        ]
      }
    }
  end

  let(:headers) do
    { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  end

  describe 'POST /api/v1/transactions' do
    context 'with valid payload' do
      it 'returns 201 created' do
        post '/api/v1/transactions', params: valid_payload.to_json, headers: headers
        expect(response).to have_http_status(:created)
      end

      it 'returns transaction_id and message' do
        post '/api/v1/transactions', params: valid_payload.to_json, headers: headers
        json = JSON.parse(response.body)
        expect(json['transaction_id']).to be_present
        expect(json['message']).to eq('Transaction saved successfully')
      end

      it 'creates a Sale record' do
        expect {
          post '/api/v1/transactions', params: valid_payload.to_json, headers: headers
        }.to change(Sale, :count).by(1)
      end

      it 'creates SaleItem records' do
        expect {
          post '/api/v1/transactions', params: valid_payload.to_json, headers: headers
        }.to change(SaleItem, :count).by(1)
      end

      it 'saves correct totals on Sale' do
        post '/api/v1/transactions', params: valid_payload.to_json, headers: headers
        sale = Sale.last
        expect(sale.subtotal).to eq(63000)
        expect(sale.tax_amount).to eq(6937)
        expect(sale.total).to eq(70000)
      end

      it 'saves correct attributes on SaleItem' do
        post '/api/v1/transactions', params: valid_payload.to_json, headers: headers
        item = SaleItem.last
        expect(item.product_name).to eq('Nasi Goreng Spesial')
        expect(item.qty).to eq(2)
        expect(item.tax_setting).to eq('tax_inclusive')
        expect(item.tax_id).to eq('indonesia_pb11%.id')
      end
    end

    context 'with multiple items' do
      let(:multi_item_payload) do
        {
          transaction: {
            subtotal: 91000,
            tax_amount: 9700,
            total: 100700,
            items: [
              {
                product_id: 1,
                product_name: 'Nasi Goreng Spesial',
                qty: 1,
                unit: 'pcs',
                unit_price: 35000,
                tax_setting: 'tax_inclusive',
                tax_rate: 11,
                tax_id: 'indonesia_pb11%.id',
                tax_amount: 3468,
                subtotal: 31532,
                total: 35000
              },
              {
                product_id: 2,
                product_name: 'Es Teh Manis',
                qty: 3,
                unit: 'pcs',
                unit_price: 8000,
                tax_setting: 'tax_exclusive',
                tax_rate: 10,
                tax_id: 'indonesia_pb10%.id',
                tax_amount: 2400,
                subtotal: 24000,
                total: 26400
              },
              {
                product_id: 4,
                product_name: 'Mineral Water',
                qty: 2,
                unit: 'pcs',
                unit_price: 5000,
                tax_setting: 'no_tax',
                tax_rate: 0,
                tax_id: nil,
                tax_amount: 0,
                subtotal: 10000,
                total: 10000
              }
            ]
          }
        }
      end

      it 'creates all sale items' do
        expect {
          post '/api/v1/transactions', params: multi_item_payload.to_json, headers: headers
        }.to change(SaleItem, :count).by(3)
      end

      it 'correctly saves no_tax item' do
        post '/api/v1/transactions', params: multi_item_payload.to_json, headers: headers
        no_tax_item = SaleItem.find_by(product_name: 'Mineral Water')
        expect(no_tax_item.tax_amount).to eq(0)
        expect(no_tax_item.tax_setting).to eq('no_tax')
        expect(no_tax_item.tax_id).to be_nil
      end
    end

    context 'with missing required fields' do
      it 'returns 422 when subtotal is missing' do
        payload = valid_payload.deep_dup
        payload[:transaction].delete(:subtotal)
        post '/api/v1/transactions', params: payload.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns 422 when total is missing' do
        payload = valid_payload.deep_dup
        payload[:transaction].delete(:total)
        post '/api/v1/transactions', params: payload.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns error messages in response body' do
        payload = valid_payload.deep_dup
        payload[:transaction].delete(:total)
        post '/api/v1/transactions', params: payload.to_json, headers: headers
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with empty items array' do
      it 'still creates the sale record' do
        payload = valid_payload.deep_dup
        payload[:transaction][:items] = []
        post '/api/v1/transactions', params: payload.to_json, headers: headers
        expect(response).to have_http_status(:created)
        expect(SaleItem.count).to eq(0)
      end
    end
  end
end