import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cart_model.dart';
import '../models/product.dart';

class ApiService {
    // Android emulator reaches host Mac via 10.0.2.2

    static const String _baseUrl = 'http://10.0.2.2:3000';

    static Future<TransactionResponse> postTransaction(CartModel cart) async {
        final uri = Uri.parse('$_baseUrl/api/v1/transactions');

        final items = cart.items.map((item) {
            final calc = item.taxResult;
            return {
                'product_id': item.product.id,
                'product_name': item.product.name,
                'qty': item.qty,
                'unit': item.product.unit,
                'unit_price': item.product.price,
                'tax_setting': _taxSettingToString(item.product.taxSetting),
                'tax_rate': item.product.taxRate,
                'tax_id': item.product.taxId,
                'tax_amount': calc.tax,
                'subtotal': calc.base,
                'total': calc.total,
            };
        }).toList();

        final body = jsonEncode({
            'transaction': {
                'subtotal': cart.subtotal,
                'tax_amount': cart.totalTax,
                'total': cart.grandTotal,
                'items': items,
            }
        });

        try {
					final response = await http
							.post(
									uri,
									headers: {
											'Content-Type': 'application/json',
											'Accept': 'application/json',
									},
									body: body
							)
							.timeout(const Duration(seconds: 10));

					if (response.statusCode == 201) {
						final json = jsonDecode(response.body);
						return TransactionResponse.success(
							transactionId: json['transaction_id'].toString(),
							message: json['message'] ?? 'Transaction saved',
						);
					} else {
						return TransactionResponse.failure(
							'Server error: ${response.statusCode}',
						);
					}
        } catch (e) {
					return TransactionResponse.failure('Network error: $e');
				}
    }

		static String _taxSettingToString(TaxSetting setting) {
			switch (setting) {
				case TaxSetting.noTax:
					return 'no_tax';
				case TaxSetting.taxInclusive:
					return 'tax_inclusive';
				case TaxSetting.taxExclusive:
					return 'tax_exclusive';
			}
		}
}

class TransactionResponse {
	final bool success;
	final String? transactionId;
	final String message;

	const TransactionResponse._({
		required this.success,
		this.transactionId,
		required this.message,
	});

	factory TransactionResponse.success({
		required String transactionId,
		required String message,
	}) =>
		TransactionResponse._(
			success: true,
			transactionId: transactionId,
			message: message
		);

	factory TransactionResponse.failure(String message) =>
		TransactionResponse._(success: false, message: message);
}