import '../core/utils/firestore_helpers.dart';

/// `carts/{userId}/items/{productId}` subcollection — one live cart per
/// consumer. Prices are re-validated server-side at checkout; the values
/// cached here are for display only.
class CartItem {
  final String productId;
  final String storeId;
  final String storeName;
  final String productName;
  final String? productImageUrl;
  final double unitPrice;
  final int quantity;
  final String unit;
  final DateTime addedAt;

  const CartItem({
    required this.productId,
    required this.storeId,
    required this.storeName,
    required this.productName,
    this.productImageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.unit,
    required this.addedAt,
  });

  double get subtotal => unitPrice * quantity;

  factory CartItem.fromMap(String id, Map<String, dynamic> map) => CartItem(
        productId: id,
        storeId: map['storeId'] ?? '',
        storeName: map['storeName'] ?? '',
        productName: map['productName'] ?? '',
        productImageUrl: map['productImageUrl'],
        unitPrice: asDouble(map['unitPrice']),
        quantity: asInt(map['quantity']),
        unit: map['unit'] ?? 'pc',
        addedAt: tsToDateOrNow(map['addedAt']),
      );

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'storeName': storeName,
        'productName': productName,
        'productImageUrl': productImageUrl,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'unit': unit,
        'addedAt': addedAt,
      };

  CartItem copyWith({int? quantity}) => CartItem(
        productId: productId,
        storeId: storeId,
        storeName: storeName,
        productName: productName,
        productImageUrl: productImageUrl,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        unit: unit,
        addedAt: addedAt,
      );
}
