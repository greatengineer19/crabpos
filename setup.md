# POS Backend — Rails API Setup Commands

## 1. Scaffold the Rails API app

```bash
rails new pos_backend --api -d postgresql
cd pos_backend
```

## 2. Drop in the files from this folder

```
app/controllers/api/v1/transactions_controller.rb
app/models/transaction.rb
app/models/transaction_item.rb
config/routes.rb
```

## 3. Generate the migrations manually

```bash
rails generate migration CreateTransactions \
  subtotal:decimal tax_amount:decimal total:decimal

rails generate migration CreateTransactionItems \
  transaction:references product_id:integer product_name:string \
  qty:integer unit:string unit_price:decimal \
  tax_setting:string tax_rate:decimal tax_id:string \
  tax_amount:decimal subtotal:decimal total:decimal
```

Then open the generated migration files and match the precision/scale values
from db/migrations.rb in this folder.

## 4. Create DB and run migrations

```bash
rails db:create
rails db:migrate
```

## 5. Allow CORS (Flutter emulator → Rails)

Add to Gemfile:
```ruby
gem 'rack-cors'
```

Then run:
```bash
bundle install
```

Create config/initializers/cors.rb:
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

## 6. Start the server

```bash
rails s
# runs on http://localhost:3000
# Flutter emulator reaches it via http://10.0.2.2:3000
```

## 7. Add http package to Flutter

In your Flutter project's pubspec.yaml:
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  http: ^1.2.0
```

Then:
```bash
flutter pub get
```

## 8. Drop in Flutter files

```
lib/services/api_service.dart       ← new file
lib/screens/summary_screen.dart     ← replace existing
```

## 9. Test the POST manually (optional)

```bash
curl -X POST http://localhost:3000/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "subtotal": 35000,
      "tax_amount": 3500,
      "total": 38500,
      "items": [{
        "product_id": 1,
        "product_name": "Nasi Goreng Spesial",
        "qty": 1,
        "unit": "pcs",
        "unit_price": 35000,
        "tax_setting": "tax_inclusive",
        "tax_rate": 11,
        "tax_id": "indonesia_pb11%.id",
        "tax_amount": 3500,
        "subtotal": 31500,
        "total": 35000
      }]
    }
  }'
```

Expected response:
```json
{ "transaction_id": 1, "message": "Transaction saved successfully" }
```