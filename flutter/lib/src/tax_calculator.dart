// lib/src/tax_calculator.dart
//
// Dart wrapper for the Rust tax-core library via flutter_rust_bridge.
//
// Both the Flutter client and the Rails backend delegate ALL tax arithmetic
// to the Rust `tax_core` crate. No tax logic lives in Dart or Ruby —
// they are thin callers only.
//
// `calculateTax` is #[frb(sync)] on the Rust side: pure math, no I/O.
// All calls in this file are therefore *synchronous* — no async, no await.
//
// Usage:
//   await initTaxLibrary();   // once in main()
//
//   // From a Product (matches product.dart TaxSetting):
//   final result = TaxCalculator.calculateForProduct(product, qty: 2);
//   print(result.tax);   // double
//   print(result.total); // double
//
//   // Low-level (region/category-based lookup):
//   final result = TaxCalculator.calculate(
//     price:     99.99,
//     region:    Region.eu,
//     category:  Category.digital,
//   );

import 'package:my_flutter_app/src/rust/api/tax.dart';
import 'package:my_flutter_app/src/rust/api/tax.dart' as bridge;
import 'package:my_flutter_app/src/rust/frb_generated.dart';

// Re-export Region + Category so callers only need one import.
export 'package:my_flutter_app/src/rust/api/tax.dart' show Region, Category;

// product.dart TaxResult / TaxSetting are intentionally NOT imported here
// to avoid a circular dependency. calculateForProduct() receives the raw
// fields it needs as plain parameters.

// ──────────────────────────────────────────────
// Result  (matches product.dart TaxResult shape)
// ──────────────────────────────────────────────

/// Tax breakdown as plain doubles — drop-in replacement for the
/// `TaxResult` produced by the old `Product.calculateTax()`.
///
/// Naming matches product.dart / cart_model.dart:
///   base  = pre-tax amount
///   tax   = tax amount
///   total = price the customer pays
class TaxResult {
  final double base;
  final double tax;
  final double total;

  const TaxResult({
    required this.base,
    required this.tax,
    required this.total,
  });

  @override
  String toString() =>
      'TaxResult(base: $base, tax: $tax, total: $total)';
}

// ──────────────────────────────────────────────
// Exception
// ──────────────────────────────────────────────

class TaxCalculatorException implements Exception {
  final String message;
  const TaxCalculatorException(this.message);

  @override
  String toString() => 'TaxCalculatorException: $message';
}

// ──────────────────────────────────────────────
// Calculator
// ──────────────────────────────────────────────

class TaxCalculator {
  TaxCalculator._();

  // ── Primary: product-level (mirrors product.dart TaxSetting logic) ────────

  /// Calculate tax for a [Product]-like set of fields.
  ///
  /// This is the replacement for `Product.calculateTax(qty)`.
  /// The caller passes the raw product fields so this file stays
  /// decoupled from `product.dart`.
  ///
  /// [price]       Unit price (double).
  /// [qty]         Quantity.
  /// [taxRatePercent]  Tax rate as a percentage (0, 10, 11, …).
  /// [noTax]       True when the product is exempt (TaxSetting.noTax).
  /// [inclusive]   True when price already includes tax (TaxSetting.taxInclusive).
  ///               False = tax-exclusive (TaxSetting.taxExclusive).
  ///
  /// Throws [TaxCalculatorException] on invalid input.
  static TaxResult calculateForProduct({
    required double price,
    required int qty,
    required double taxRatePercent,
    required bool noTax,
    required bool inclusive,
  }) {
    final lineTotal = price * qty;

    if (noTax || taxRatePercent == 0) {
      return TaxResult(base: lineTotal, tax: 0, total: lineTotal);
    }

    // Delegate to Rust — fraction = percent / 100
    final raw = _callRust(
      price:     lineTotal,
      customRate: taxRatePercent / 100,
      inclusive:  inclusive,
    );

    return TaxResult(
      base:  double.parse(raw.priceBeforeTax),
      tax:   double.parse(raw.taxAmount),
      total: double.parse(raw.priceAfterTax),
    );
  }

  // ── Low-level: region/category-based lookup ───────────────────────────────

  /// Calculate tax using the Rust rate table (region + category lookup).
  ///
  /// [price]      Pre-tax (or inclusive) price as double.
  /// [region]     Tax region (default: [Region.us]).
  /// [category]   Product category (default: [Category.general]).
  /// [customRate] Override rate as a fraction 0…1, e.g. 0.075 for 7.5%.
  ///              Pass `null` to use the region/category default.
  /// [inclusive]  true = price already includes tax, false = price is pre-tax.
  static TaxResult calculate({
    required double price,
    Region region = Region.us,
    Category category = Category.general,
    double? customRate,
    bool inclusive = false,
  }) {
    final raw = bridge.calculateTax(
      price:      _decStr(price),
      region:     region,
      category:   category,
      customRate: customRate != null ? _decStr(customRate) : '',
      inclusive:  inclusive,
    );

    return TaxResult(
      base:  double.parse(raw.priceBeforeTax),
      tax:   double.parse(raw.taxAmount),
      total: double.parse(raw.priceAfterTax),
    );
  }

  /// Effective rate for a region+category as a fraction (e.g. 0.2 for EU/Digital).
  static double effectiveRate(Region region, Category category) =>
      double.parse(bridge.getEffectiveRate(region: region, category: category));

  /// Effective rate as a percentage (e.g. 20.0 for EU/Digital).
  static double effectiveRatePercent(Region region, Category category) =>
      effectiveRate(region, category) * 100;

  // ── private ───────────────────────────────────────────────────────────────

  /// Call Rust with a custom_rate override (always Region.custom).
  static bridge.TaxBreakdown _callRust({
    required double price,
    required double customRate,
    required bool inclusive,
  }) {
    return bridge.calculateTax(
      price:      _decStr(price),
      region:     Region.custom,
      category:   Category.general,
      customRate: _decStr(customRate),
      inclusive:  inclusive,
    );
  }

  /// Serialise a double to a DECIMAL(20,6) string for the Rust boundary.
  static String _decStr(double v) => v.toStringAsFixed(6);
}

// ──────────────────────────────────────────────
// Initialisation
// ──────────────────────────────────────────────

/// Call once in `main()` before any [TaxCalculator] call.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initTaxLibrary();
///   runApp(const MyApp());
/// }
/// ```
Future<void> initTaxLibrary() => RustLib.init();
