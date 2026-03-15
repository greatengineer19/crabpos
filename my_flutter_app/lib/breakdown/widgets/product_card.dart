import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/cart_model.dart';

class ProductCard extends StatelessWidget {
    final Product product;

    const ProductCard({ super.key, required this.product });

    @override
    Widget build(BuildContext context) {
        final cart = context.watch<CartModel>();
        final qty = cart.getQty(product.id);
        final isSelected = qty > 0;

        return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1A1F2E)
                    : const Color(0xFF12151F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isSelected
                        ? _accentColor
                        : const Color(0xFF1E2535),
                    width: 1.5,
                ),
            ),
            child: Stack(
                children: [
                    Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(product.emoji, style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 8),
                                Text(
                                    product.name,
                                    style: const TextStyle(
                                        color: Color(0xFFE8EAF6),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    '${product.unit} · ${product.taxLabel}',
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 11,
                                    ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                    _formatRupiah(product.price),
                                    style: TextStyle(
                                        color: _accentColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                ),
                                const Spacer(),
                                _QtyControl(product: product, qty: qty),
                            ]
                        )
                    ),
                    if (isSelected)
                        Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                    color: _accentColor,
                                    borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(14),
                                        bottomLeft: Radius.circular(10),
                                    )
                                ),
                                child: Text(
                                    'x$qty',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                )
                            )
                            ),
                        )
                ]
            )
        );
    }

    Color get _accentColor => const Color(0xFFA78BFA);

    String _formatRupiah(double amount) {
        final formatted = amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
        );
        return 'Rp $formatted';
    }
}

class _QtyControl extends StatelessWidget {
    final Product product;
    final int qty;

    const _QtyControl({ required this.product, required this.qty });

    @override
    Widget build(BuildContext context) {
        final cart = context.read<CartModel>();

        return Row(
            children: [
                _CircleBtn(
                    icon: Icons.remove,
                    enabled: qty > 0,
                    onTap: () => cart.remove(product),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    width: 20,
                    child: Text(
                        '$qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFE8EAF6),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                        ),
                    ),
                ),
                const SizedBox(width: 8),
                _CircleBtn(
                    icon: Icons.add,
                    enabled: true,
                    onTap: () => cart.add(product),
                )
            ]
        );
    }
}

class _CircleBtn extends StatelessWidget {
    final IconData icon;
    final bool enabled;
    final VoidCallback onTap;

    const _CircleBtn({
        required this.icon,
        required this.enabled,
        required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onTap: enabled ? onTap : null,
            child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: enabled
                        ? (icon == Icons.add
                            ? const Color(0xFFA78BFA)
                            : const Color(0xFF1E2535))
                        : const Color(0xFF0D1017),
                    borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                    icon,
                    size: 16,
                    color: enabled ? Colors.white : const Color(0xFF3A3F50),
                )
            )
        );
    }
}