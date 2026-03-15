import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart_model.dart';
import '../../models/mock_products.dart';
import '../widgets/product_card.dart';
import 'summary_screen.dart';

class PosScreen extends StatefulWidget {
    const PosScreen({ super.key });

    @override
    State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
    String _selectedCategory = 'All';

    List<String> get _categories {
        final cats = mockProducts.map((p) => p.category).toSet().toList();
        return ['All', ...cats];
    }

    @override
    Widget build(BuildContext context) {
        final cart = context.watch<CartModel>();
        final filtered = _selectedCategory == 'All'
            ? mockProducts
            : mockProducts.where((p) => p.category == _selectedCategory).toList();

        return Scaffold(
            backgroundColor: const Color(0xFF0A0D14),
            body: SafeArea(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        _buildHeader(cart),
                        _buildCategoryFilter(),
                        Expanded(
                            child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.72,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) => ProductCard(product: filtered[i]),
                            ),
                        ),
                        if (cart.totalItems > 0) _buildCheckoutBar(context, cart),
                    ],
                )
            )
        );
    }

    Widget _buildHeader(CartModel cart) {
        return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            const Text(
                                'Add Product',
                                style: TextStyle(
                                    color: Color(0xFFE8EAF6),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                                'Select items to sell',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                            ),
                        ],
                    ),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1A1F2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF2D3348)),
                        ),
                        child: Text(
                            '${cart.totalItems} item${cart.totalItems != 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: Color(0xFFA78BFA),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                            )
                        )
                    )
                ]
            )
        );
    }

    Widget _buildCategoryFilter() {
        return SizedBox(
            height: 48,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                    final cat = _categories[i];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFA78BFA)
                                    : const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                                cat,
                                style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                )
                            )
                        )
                    );
                }
            )
        );
    }

    Widget _buildCheckoutBar(BuildContext context, CartModel cart) {
        return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
                color: Color(0xFF0A0D14),
                border: Border(top: BorderSide(color: Color(0xFF1E2535))),
            ),
            child: GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SummaryScreen()),
                ),
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFA78BFA), Color(0xFF818CF8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFA78BFA).withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 4),
                            )
                        ]
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                                '🛒 Checkout (${cart.totalItems})',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                ),
                            ),
                            Text(
                                _formatRupiah(cart.grandTotal),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                )
                            )
                        ]
                    )
                )
            )
        );
    }

    String _formatRupiah(double amount) {
        final formatted = amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
        );
        return 'Rp $formatted';
    }
}