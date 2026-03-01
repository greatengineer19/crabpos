# 🦀 tax-calculator  (offline shared library)

A **pure-Rust tax engine** compiled to a native shared library — no HTTP server,
no network, works fully offline.  Both Ruby on Rails and Flutter call the same
compiled binary directly.

---

## Project structure

```
tax-calculator/
├── Cargo.toml                    # Workspace root
│
├── tax-core/                     # ★ Core library — pure logic, zero deps
│   ├── Cargo.toml
│   └── src/lib.rs                # Rust API + C ABI (cdylib / staticlib / rlib)
│
├── flutter-integration/          # flutter_rust_bridge wrapper
│   ├── Cargo.toml
│   ├── src/lib.rs                # Bridge API (frb macros)
│   └── lib/tax_calculator.dart   # Dart wrapper + example widget
│
└── rails-integration/
    └── lib/tax_calculator.rb     # Ruby FFI binding + TaxCalculator class
```

---

## How it works

```
┌───────────────────────────────────────────────────────┐
│                     tax-core                          │
│   Pure Rust — decimal arithmetic, no I/O, no alloc    │
│                                                       │
│  ┌──────────────┐            ┌─────────────────────┐  │
│  │  Rust rlib   │────────────▶  flutter-integration │  │
│  │  (rlib)      │            │  (frb + cdylib)      │  │
│  └──────────────┘            └──────────┬──────────┘  │
│                                         │              │
│  ┌──────────────────────────────────┐   │              │
│  │  C ABI  (cdylib / staticlib)     │   │ codegen      │
│  │  tax_calculate()                 │   ▼              │
│  │  tax_effective_rate_bps()        │  Flutter app     │
│  └──────────┬───────────────────────┘  (Dart)         │
│             │                                         │
│             ▼                                         │
│        Ruby FFI                                       │
│        Rails app                                      │
└───────────────────────────────────────────────────────┘
```

---

## Build

```bash
# Build everything (debug)
cargo build

# Build release shared library (what Rails and Flutter use)
cargo build --release

# Artifacts:
#   target/release/libtax_core.so       (Linux  — Ruby FFI)
#   target/release/libtax_core.dylib    (macOS  — Ruby FFI)
#   target/release/libtax_core.a        (static — mobile embedding)
#   target/release/libflutter_tax.so    (Linux  — Flutter cdylib)
```

```bash
# Run all tests
cargo test
```

---

## Rails integration

### 1. Build the library
```bash
cargo build --release
# sets TAX_CORE_LIB=/path/to/libtax_core.so in your env
```

### 2. Install the gem
```ruby
# Gemfile
gem 'ffi'
```

### 3. Copy & require
```bash
cp rails-integration/lib/tax_calculator.rb app/lib/
```

```ruby
# config/initializers/tax_calculator.rb
require_relative "../../lib/tax_calculator"
```

### 4. Use in a controller / service
```ruby
calc = TaxCalculator.new

# price_cents avoids all floating-point issues
result = calc.calculate(
  price_cents:    9999,      # $99.99
  region:         "EU",
  category:       "DIGITAL",
)

result.price_after_tax       # => 119.99  (Float, for display)
result.price_after_tax_cents # => 11999   (decimal, store in DB)
result.rate_display          # => "20.00 %"
result.tax_amount            # => 20.0

# Get just the rate (fast, no full calculation)
calc.effective_rate_bps(region: "EU", category: "LUXURY") # => 2500
```

### 5. Environment variable for the library path
```bash
# .env / production env
TAX_CORE_LIB=/opt/app/lib/libtax_core.so
```

---

## Flutter integration

### 1. Add the dependency
```yaml
# pubspec.yaml
dependencies:
  flutter_rust_bridge: ^2.0.0

dev_dependencies:
  flutter_rust_bridge_codegen: ^2.0.0
```

### 2. Generate Dart bindings
```bash
flutter_rust_bridge_codegen generate
# reads:   flutter-integration/src/lib.rs
# writes:  lib/src/rust/api/tax.dart  (+ glue files)
```

### 3. Copy the wrapper
```bash
cp flutter-integration/lib/tax_calculator.dart lib/src/tax/
```

### 4. Use in a widget
```dart
import 'package:your_app/src/tax/tax_calculator.dart';

final result = await TaxCalculator.calculate(
  priceCents: 9999,           // 99.99 in the currency's smallest unit
  region:     Region.eu,
  category:   Category.digital,
);

print(result.rateDisplay);         // "20.00 %"
print(result.priceAfterTaxCents);  // 11999
print(result.priceAfterTax);       // 119.99
print(result.currency);            // "EUR"

// Get just the rate
final bps = await TaxCalculator.effectiveRateBps(Region.eu, Category.luxury);
// bps == 2500  (25.00 %)
```

---

## Tax rules

| Region | General | Food | Medicine | Digital | Luxury |
|--------|---------|------|----------|---------|--------|
| US     | 8 %     | 8 %  | 8 %      | 8 %     | 8 %    |
| EU     | 20 %    | 0 %  | 0 %      | 20 %    | 25 %   |
| UK     | 20 %    | 0 %  | 0 %      | 20 %    | 20 %   |
| AU     | 10 %    | 10 % | 0 %      | 10 %    | 10 %   |

Pass `custom_rate_bps: 700` (= 7 %) to override any region rule.