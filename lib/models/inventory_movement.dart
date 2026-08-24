import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `inventory_movements` collection — append-only audit trail. Every
/// inventory-affecting action in the app (sale, reservation, stock-in,
/// damage, etc.) must write exactly one of these via the Cloud Function
/// that also mutates the product document, inside the same transaction.
class InventoryMovement {
  final String id;
  final String productId;
  final String storeId;
  final MovementType type;
  final int quantityBefore;
  final int quantityChanged; // signed: positive = stock increased
  final int quantityAfter;
  final String reason;
  final String? relatedOrderId;
  final String? relatedReservationId;
  final String? relatedDeliveryId;
  final String performedByUserId;
  final String performedByName;
  final DateTime createdAt;

  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.storeId,
    required this.type,
    required this.quantityBefore,
    required this.quantityChanged,
    required this.quantityAfter,
    required this.reason,
    this.relatedOrderId,
    this.relatedReservationId,
    this.relatedDeliveryId,
    required this.performedByUserId,
    required this.performedByName,
    required this.createdAt,
  });

  factory InventoryMovement.fromMap(String id, Map<String, dynamic> map) => InventoryMovement(
        id: id,
        productId: map['productId'] ?? '',
        storeId: map['storeId'] ?? '',
        type: MovementTypeX.fromName(map['type'] ?? 'manualAdjustment'),
        quantityBefore: asInt(map['quantityBefore']),
        quantityChanged: asInt(map['quantityChanged']),
        quantityAfter: asInt(map['quantityAfter']),
        reason: map['reason'] ?? '',
        relatedOrderId: map['relatedOrderId'],
        relatedReservationId: map['relatedReservationId'],
        relatedDeliveryId: map['relatedDeliveryId'],
        performedByUserId: map['performedByUserId'] ?? '',
        performedByName: map['performedByName'] ?? '',
        createdAt: tsToDateOrNow(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'storeId': storeId,
        'type': type.name,
        'quantityBefore': quantityBefore,
        'quantityChanged': quantityChanged,
        'quantityAfter': quantityAfter,
        'reason': reason,
        'relatedOrderId': relatedOrderId,
        'relatedReservationId': relatedReservationId,
        'relatedDeliveryId': relatedDeliveryId,
        'performedByUserId': performedByUserId,
        'performedByName': performedByName,
      };
}
