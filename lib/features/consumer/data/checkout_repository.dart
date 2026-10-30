import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/cart_item.dart';

class CheckoutException implements Exception {
  final String message;
  CheckoutException(this.message);
  @override
  String toString() => message;
}

class CheckoutGroup {
  final String storeId;
  final FulfillmentType fulfillmentType;
  final String? deliveryAddressId;
  final String? deliveryAddressText;
  final String? notes;
  final PaymentMethod paymentMethod;
  final List<CartItem> items;

  CheckoutGroup({
    required this.storeId,
    required this.fulfillmentType,
    this.deliveryAddressId,
    this.deliveryAddressText,
    this.notes,
    required this.paymentMethod,
    required this.items,
  });

  double get subtotal => items.fold(0, (sum, i) => sum + i.subtotal);
}

/// Thin client for the `processCheckout` Cloud Function — all pricing and
/// stock validation happens server-side (§20); this just shapes the
/// request and surfaces errors in a form the UI can show directly.
class CheckoutRepository {
  final FirebaseAuth _auth;
  CheckoutRepository(this._auth);

  Future<List<String>> checkout(List<CheckoutGroup> groups) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw CheckoutException('Not signed in.');
      final token = await user.getIdToken();
      final uri = Uri.parse('https://salwanaapp.onrender.com/processCheckout');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'idempotencyKey': const Uuid().v4(),
          'groups': groups
              .map((g) => {
                    'storeId': g.storeId,
                    'fulfillmentType': g.fulfillmentType.name,
                    'deliveryAddressId': g.deliveryAddressId,
                    'deliveryAddressText': g.deliveryAddressText,
                    'notes': g.notes,
                    'paymentMethod': g.paymentMethod.name,
                    'items': g.items.map((i) => {'productId': i.productId, 'quantity': i.quantity}).toList(),
                  })
              .toList(),
        }),
      );
      if (resp.statusCode >= 400) {
        final body = jsonDecode(resp.body);
        throw CheckoutException(body['error'] ?? 'Checkout failed. Please try again.');
      }
      final data = jsonDecode(resp.body);
      final orderIds = (data['orderIds'] as List?)?.cast<String>() ?? const [];
      return orderIds;
    } catch (e) {
      if (e is CheckoutException) rethrow;
      throw CheckoutException(e.toString());
    }
  }
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(firebaseAuthProvider));
});
