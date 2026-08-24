import '../core/utils/firestore_helpers.dart';

/// Line item embedded in an `orders` document's `items` array.
class OrderItem {
  final String productId;
  final String productName;
  final String? productImageUrl;
  final double unitPrice;
  final int quantity;
  final String unit;
  final double subtotal;

  const OrderItem({
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.unit,
    required this.subtotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] ?? '',
        productName: map['productName'] ?? '',
        productImageUrl: map['productImageUrl'],
        unitPrice: asDouble(map['unitPrice']),
        quantity: asInt(map['quantity']),
        unit: map['unit'] ?? 'pc',
        subtotal: asDouble(map['subtotal']),
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'productImageUrl': productImageUrl,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'unit': unit,
        'subtotal': subtotal,
      };
}
