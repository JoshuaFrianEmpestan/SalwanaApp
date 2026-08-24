import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `reservations` collection.
class Reservation {
  final String id;
  final String consumerId;
  final String consumerName;
  final String storeId;
  final String storeName;
  final String merchantId;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final int quantity;
  final double unitPrice;
  final FulfillmentType fulfillmentType;
  final DateTime scheduledFor;
  final ReservationStatus status;
  final String? rejectionReason;
  final DateTime expiresAt;
  final bool reminderSent;
  final String? deliveryAddressText;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Reservation({
    required this.id,
    required this.consumerId,
    required this.consumerName,
    required this.storeId,
    required this.storeName,
    required this.merchantId,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.quantity,
    required this.unitPrice,
    required this.fulfillmentType,
    required this.scheduledFor,
    required this.status,
    this.rejectionReason,
    required this.expiresAt,
    this.reminderSent = false,
    this.deliveryAddressText,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get total => unitPrice * quantity;

  factory Reservation.fromMap(String id, Map<String, dynamic> map) => Reservation(
        id: id,
        consumerId: map['consumerId'] ?? '',
        consumerName: map['consumerName'] ?? '',
        storeId: map['storeId'] ?? '',
        storeName: map['storeName'] ?? '',
        merchantId: map['merchantId'] ?? '',
        productId: map['productId'] ?? '',
        productName: map['productName'] ?? '',
        productImageUrl: map['productImageUrl'],
        quantity: asInt(map['quantity']),
        unitPrice: asDouble(map['unitPrice']),
        fulfillmentType: FulfillmentTypeX.fromName(map['fulfillmentType'] ?? 'pickup'),
        scheduledFor: tsToDateOrNow(map['scheduledFor']),
        status: ReservationStatusX.fromName(map['status'] ?? 'pending'),
        rejectionReason: map['rejectionReason'],
        expiresAt: tsToDateOrNow(map['expiresAt']),
        reminderSent: map['reminderSent'] ?? false,
        deliveryAddressText: map['deliveryAddressText'],
        notes: map['notes'],
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'consumerId': consumerId,
        'consumerName': consumerName,
        'storeId': storeId,
        'storeName': storeName,
        'merchantId': merchantId,
        'productId': productId,
        'productName': productName,
        'productImageUrl': productImageUrl,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'fulfillmentType': fulfillmentType.name,
        'scheduledFor': scheduledFor,
        'status': status.name,
        'rejectionReason': rejectionReason,
        'expiresAt': expiresAt,
        'reminderSent': reminderSent,
        'deliveryAddressText': deliveryAddressText,
        'notes': notes,
      };
}
