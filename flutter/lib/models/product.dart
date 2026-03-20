// lib/models/product.dart
//
// Tax calculation is NOT performed here. The single source of truth is the
// Rust `tax_core` crate, called through `TaxCalculator.calculateForProduct()`.
//
// TaxResult is kept here as a plain value object because cart_model.dart and
// summary_screen.dart depend on its {base, tax, total} shape.

import '../src/tax_calculator.dart' show TaxCalculator, TaxResult;

export '../src/tax_calculator.dart' show TaxResult;

enum TaxSetting { noTax, taxInclusive, taxExclusive }

class Product {
    final int id;
    final String name;
    final String category;
    final double price;
    final String unit;
    final TaxSetting taxSetting;
    final double taxRate; // percentage: 0, 10, or 11
    final String? taxId;
    final String emoji;

    const Product({
        required this.id,
        required this.name,
        required this.category,
        required this.price,
        required this.unit,
        required this.taxSetting,
        required this.taxRate,
        this.taxId,
        required this.emoji,
    });

    /// Delegates to Rust via [TaxCalculator]. No tax arithmetic in Dart.
    TaxResult calculateTax(int qty) => TaxCalculator.calculateForProduct(
        price:          price,
        qty:            qty,
        taxRatePercent: taxRate,
        noTax:          taxSetting == TaxSetting.noTax,
        inclusive:      taxSetting == TaxSetting.taxInclusive,
    );

    String get taxLabel {
        switch (taxSetting) {
            case TaxSetting.noTax:
                return 'No Tax';
            case TaxSetting.taxInclusive:
                return 'Incl. Tax ${taxRate.toInt()}%';
            case TaxSetting.taxExclusive:
                return 'Excl. Tax ${taxRate.toInt()}%';
        }
    }
}