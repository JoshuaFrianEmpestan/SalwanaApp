import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';
import 'order_item.dart';

/// `orders` collection. One order == one merchant's items from a checkout;
/// a multi-merchant cart is split into several orders sharing a
/// `checkoutGroupId` so the receipt/history screens can group them.
class Order {
  final String id;
  final String checkoutGroupId;
  final String consumerId;
  final String consumerName;
  final String storeId;
  final String storeName;
  final String merchantId;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double platformFee;
  final double total;
  final PaymentMethod paymentMethod;
  final OrderStatus status;
  final FulfillmentType fulfillmentType;
  final String? deliveryAddressId;
  final String? deliveryAddressText;
  final String? notes;
  final String? cancellationReason;
  final bool reviewed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.checkoutGroupId,
    required this.consumerId,
    required this.consumerName,
    required this.storeId,
    required this.storeName,
    required this.merchantId,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 0,
    this.discount = 0,
    this.platformFee = 0,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.fulfillmentType,
    this.deliveryAddressId,
    this.deliveryAddressText,
    this.notes,
    this.cancellationReason,
    this.reviewed = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromMap(String id, Map<String, dynamic> map) => Order(
        id: id,
        checkoutGroupId: map['checkoutGroupId'] ?? '',
        consumerId: map['consumerId'] ?? '',
        consumerName: map['consumerName'] ?? '',
        storeId: map['storeId'] ?? '',
        storeName: map['storeName'] ?? '',
        merchantId: map['merchantId'] ?? '',
        items: ((map['items'] as List?) ?? const [])
            .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        subtotal: asDouble(map['subtotal']),
        deliveryFee: asDouble(map['deliveryFee']),
        discount: asDouble(map['discount']),
        platformFee: asDouble(map['platformFee']),
        total: asDouble(map['total']),
        paymentMethod: PaymentMethodX.fromName(map['paymentMethod'] ?? 'simulated'),
        status: OrderStatusX.fromName(map['status'] ?? 'pendingPayment'),
        fulfillmentType: FulfillmentTypeX.fromName(map['fulfillmentType'] ?? 'pickup'),
        deliveryAddressId: map['deliveryAddressId'],
        deliveryAddressText: map['deliveryAddressText'],
        notes: map['notes'],
        cancellationReason: map['cancellationReason'],
        reviewed: map['reviewed'] ?? false,
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'checkoutGroupId': checkoutGroupId,
        'consumerId': consumerId,
        'consumerName': consumerName,
        'storeId': storeId,
        'storeName': storeName,
        'merchantId': merchantId,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'discount': discount,
        'platformFee': platformFee,
        'total': total,
        'paymentMethod': paymentMethod.name,
        'status': status.name,
        'fulfillmentType': fulfillmentType.name,
        'deliveryAddressId': deliveryAddressId,
        'deliveryAddressText': deliveryAddressText,
        'notes': notes,
        'cancellationReason': cancellationReason,
        'reviewed': reviewed,
      };
}
