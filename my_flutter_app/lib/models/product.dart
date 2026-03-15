enum TaxSetting { noTax, taxInclusive, taxExclusive }

class Product {
    final int id;
    final String name;
    final String category;
    final double price;
    final String unit;
    final TaxSetting taxSetting;
    final double taxRate; // 0, 10, or 11
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

    TaxResult calculateTax(int qty) {
        final lineTotal = price * qty;

        if (taxSetting == TaxSetting.noTax || taxRate == 0) {
            return TaxResult(
                base: lineTotal,
                tax: 0,
                total: lineTotal
            );
        }

        if (taxSetting == TaxSetting.taxInclusive) {
            final base = lineTotal / (1 + taxRate / 100);
            final tax = lineTotal - base;
            return TaxResult(
                base: base,
                tax: tax,
                total: lineTotal
            );
        }

        final tax = lineTotal * (taxRate / 100);
        return TaxResult(
            base: lineTotal,
            tax: tax,
            total: lineTotal + tax
        );
    }

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

class TaxResult {
    final double base;
    final double tax;
    final double total;

    const TaxResult({
        required this.base,
        required this.tax,
        required this.total,
    });
}