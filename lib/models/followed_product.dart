import '../core/utils/firestore_helpers.dart';

/// `followed_products` collection — consumer follows a store or product to
/// receive a Back-in-Stock notification. `productId` is null for a
/// store-level follow.
class FollowedProduct {
  final String id;
  final String consumerId;
  final String storeId;
  final String storeName;
  final String? productId;
  final String? productName;
  final DateTime createdAt;

  const FollowedProduct({
    required this.id,
    required this.consumerId,
    required this.storeId,
    required this.storeName,
    this.productId,
    this.productName,
    required this.createdAt,
  });

  factory FollowedProduct.fromMap(String id, Map<String, dynamic> map) => FollowedProduct(
        id: id,
        consumerId: map['consumerId'] ?? '',
        storeId: map['storeId'] ?? '',
        storeName: map['storeName'] ?? '',
        productId: map['productId'],
        productName: map['productName'],
        createdAt: tsToDateOrNow(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'consumerId': consumerId,
        'storeId': storeId,
        'storeName': storeName,
        'productId': productId,
        'productName': productName,
      };
}
