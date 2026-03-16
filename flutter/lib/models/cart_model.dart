import 'package:flutter/foundation.dart';
import 'product.dart';

class CartItem {
    final Product product;
    int qty;

    CartItem({ required this.product, required this.qty });
    TaxResult get taxResult => product.calculateTax(qty);
}

class CartModel extends ChangeNotifier {
    final Map<int, CartItem> _items = {};

    List<CartItem> get items => _items.values.where((i) => i.qty > 0).toList();

    int getQty(int productId) => _items[productId]?.qty ?? 0;

    int get totalItems => _items.values.fold(0, (sum, i) => sum + i.qty);

    double get grandTotal => items.fold(0, (sum, i) => sum + i.taxResult.total);

    double get subtotal => items.fold(0, (sum, i) => sum + i.taxResult.base);

    double get totalTax => items.fold(0, (sum, i) => sum + i.taxResult.tax);

    /// Returns tax grouped by taxId: { taxId -> { label, rate, amount } }
    Map<String, TaxBreakdown> get taxBreakdown {
        final map = <String, TaxBreakdown>{};
        for (final item in items) {
            if (item.taxResult.tax == 0) continue;
            final key = item.product.taxId ?? 'other';
            final label = 'PPN ${item.product.taxRate.toInt()} (${item.product.taxId ?? 'Tax'})';
            map[key] ??= TaxBreakdown(label: label, rate: item.product.taxRate, amount: 0);
            map[key] = map[key]!.copyWith(amount: map[key]!.amount + item.taxResult.tax);
        }
        return map;
    }

    void add(Product product) {
        if (_items.containsKey(product.id)) {
            _items[product.id]!.qty++;
        } else {
            _items[product.id] = CartItem(product: product, qty: 1);
        }
        notifyListeners();
    }
    
    void remove(Product product) {
        if (!_items.containsKey(product.id)) return;
        if (_items[product.id]!.qty <= 1) {
            _items.remove(product.id);
        } else {
            _items[product.id]!.qty--;
        }
        notifyListeners();
    }

    void clear() {
        _items.clear();
        notifyListeners();
    }
}

class TaxBreakdown {
    final String label;
    final double rate;
    final double amount;

    const TaxBreakdown({ required this.label, required this.rate, required this.amount });
    TaxBreakdown copyWith({ double? amount }) =>
        TaxBreakdown(
            label: label,
            rate: rate,
            amount: amount ?? this.amount,
        );
}