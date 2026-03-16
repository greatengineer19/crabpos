import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cart_model.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';

class SummaryScreen extends StatefulWidget {
    const SummaryScreen({ super.key });

    @override
    State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
    bool _isLoading = false;
    
    Future<void> _confirmPayment(CartModel cart) async {
        setState(() => _isLoading = true);

        final response = await ApiService.postTransaction(cart);

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (response.success) {
            cart.clear();
                    Navigator.popUntil(context, (route) => route.isFirst);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                        content: Text('✅ Transaction #${response.transactionId} saved!'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 3),
                ),
            );
        } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                content: Text('❌ ${response.message}'),
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 4),
                ),
            );
        }
    }

    @override
    Widget build(BuildContext context) {
        final cart = context.watch<CartModel>();

        return Scaffold(
            backgroundColor: const Color(0xFF0A0D14),
            body: SafeArea(
                child: Column(
                    children: [
                        _buildHeader(context),
                        Expanded(
                            child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                    _buildSectionLabel('Items'),
                                    const SizedBox(height: 8),
                                    _buildItemsCard(cart),
                                    if (cart.taxBreakdown.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        _buildSectionLabel('Tax Summary'),
                                        const SizedBox(height: 8),
                                        _buildTaxBreakdownCard(cart),
                                    ],
                                    const SizedBox(height: 16),
                                    _buildTotalsCard(cart),
                                    const SizedBox(height: 24),
                                ],
                            ),
                        ),
                        _buildPayButton(context, cart),
                    ]
                )
            )
        );
    }

    Widget _buildHeader(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
                children: [
                    GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: const Color(0xFF12151F),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF1E2535)),
                            ),
                            child: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Color(0xFFE8EAF6),
                                size: 16,
                            ),
                        ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                            Text(
                                'Order Summary',
                                style: TextStyle(
                                    color: Color(0xFFE8EAF6),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5
                                ),
                            ),
                            SizedBox(height: 2),
                            Text(
                                'Review before payment',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                            )
                        ]
                    )
                ]
            )
        );
    }

    Widget _buildSectionLabel(String label) {
        return Text(
            label.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
            )
        );
    }

    Widget _buildItemsCard(CartModel cart) {
        return _Card(
            children: cart.items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final calc = item.taxResult;
                final isLast = i == cart.items.length - 1;

                return _CardRow(
                    isLast: isLast,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(item.product.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Text(
                                            item.product.name,
                                            style: const TextStyle(
                                                color: Color(0xFFE8EAF6),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700
                                            ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                            children: [
                                                Text(
                                                    '${_fmt(item.product.price)} × ${item.qty} ${item.product.unit}',
                                                    style: const TextStyle(
                                                        color: Color(0xFF6B7280),
                                                        fontSize: 11,
                                                    ),
                                                ),
                                                if (item.product.taxSetting != TaxSetting.noTax) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 6, vertical: 1
                                                        ),
                                                        decoration: BoxDecoration(
                                                            color: const Color(0xFF1E2535),
                                                            borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                            item.product.taxLabel,
                                                            style: const TextStyle(
                                                                color: Color(0xFFA78BFA),
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w600,
                                                            )
                                                        )
                                                    )
                                                ]
                                            ]
                                        )
                                    ]
                                )
                            ),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                    Text(
                                        _fmt(calc.total),
                                        style: const TextStyle(
                                            color: Color(0xFFE8EAF6),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                    ),
                                    if (calc.tax > 0)
                                        Text(
                                            'tax: ${_fmt(calc.tax)}',
                                            style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontSize: 11
                                            )
                                        )
                                ]
                            )
                        ]
                    )
                );
            }).toList(),
        );
    }

    Widget _buildTaxBreakdownCard(CartModel cart) {
        final entries = cart.taxBreakdown.entries.toList();
        return _Card(
            children: entries.asMap().entries.map((e) {
                final i = e.key;
                final tb = e.value.value;

                return _CardRow(
                    isLast: i == entries.length - 1,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        tb.label,
                                        style: const TextStyle(
                                            color: Color(0xFFC4B5FD),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                        ),
                                    ),
                                    Text(
                                        'Rate ${tb.rate.toInt()}%',
                                        style: const TextStyle(
                                            color: Color(0xFF6B7280), fontSize: 11
                                        )
                                    )
                                ]
                            ),
                            Text(
                                _fmt(tb.amount),
                                style: const TextStyle(
                                    color: Color(0xFFC4B5FD),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                )
                            )
                        ]
                    )
                );
            }).toList(),
        );
    }

    Widget _buildTotalsCard(CartModel cart) {
        return _Card(
            children: [
                _CardRow(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            const Text('Subtotal (before tax)',
                                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)
                            ),
                            Text(
                                _fmt(cart.subtotal),
                                style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                )
                            )
                        ]
                    )
                ),
                _CardRow(
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            const Text('Total Tax',
                                style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 13)
                            ),
                            Text(
                                _fmt(cart.totalTax),
                                style: const TextStyle(
                                    color: Color(0xFFC4B5FD),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()]
                                )
                            )
                        ]
                    )
                ),
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                                const Color(0xFFA78BFA).withOpacity(0.1),
                                const Color(0xFF818CF8).withOpacity(0.1),
                            ],
                        ),
                        borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                        ),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            const Text(
                                'Grand Total',
                                style: TextStyle(
                                    color: Color(0xFFE8EAF6),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                ),
                            ),
                            Text(
                                _fmt(cart.grandTotal),
                                style: const TextStyle(
                                    color: Color(0xFFA78BFA),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                )
                            )
                        ]
                    )
                )
            ]
        );
    }

    Widget _buildPayButton(BuildContext context, CartModel cart) {
        return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
                color: Color(0xFF0A0D14),
                border: Border(
                    top: BorderSide(color: Color(0xFF1E2535)),
                ),
            ),
            child: GestureDetector(
                onTap: _isLoading ? null : () => _confirmPayment(cart),
                child: AnimatedOpacity(
                    opacity: _isLoading ? 0.7 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 4),
                                ),
                            ],
                        ),
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                ),
                            )
                            : Text(
                                '✓  Confirm Payment · ${_fmt(cart.grandTotal)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                ),
                            ),
                    ),
                ),
            ),
        );
    }

    String _fmt(double amount) {
        final formatted = amount.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
        return 'Rp $formatted';
    }
}

// --- Reusable card components --------------------
class _Card extends StatelessWidget {
    final List<Widget> children;
    const _Card({ required this.children });

    @override
    Widget build(BuildContext context) {
        return Container(
            decoration: BoxDecoration(
                color: const Color(0xFF12151F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E2535)),
            ),
            child: Column(children: children),
        );
    }
}

class _CardRow extends StatelessWidget {
    final Widget child;
    final bool isLast;
    const _CardRow({ required this.child, this.isLast = false });

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1A1F2E))),
            ),
            child: child,
        );
    }
}
