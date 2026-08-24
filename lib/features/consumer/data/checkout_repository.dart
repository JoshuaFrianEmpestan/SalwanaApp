import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
  final FirebaseFunctions _functions;
  CheckoutRepository(this._functions);

  Future<List<String>> checkout(List<CheckoutGroup> groups) async {
    try {
      final callable = _functions.httpsCallable('processCheckout');
      final result = await callable.call<Map<String, dynamic>>({
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
      });
      final orderIds = (result.data['orderIds'] as List?)?.cast<String>() ?? const [];
      return orderIds;
    } on FirebaseFunctionsException catch (e) {
      throw CheckoutException(e.message ?? 'Checkout failed. Please try again.');
    }
  }
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.watch(firebaseFunctionsProvider));
});
