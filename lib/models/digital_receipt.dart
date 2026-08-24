import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';
import 'order_item.dart';

/// `digital_receipts` collection — generated once an order/payment reaches
/// a paid/completed state. Immutable once created.
class DigitalReceipt {
  final String id;
  final String receiptNumber;
  final String orderId;
  final String storeName;
  final String storePhone;
  final String storeEmail;
  final String consumerName;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double platformFee;
  final double total;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final OrderStatus orderStatus;
  final String transactionReference;
  final DateTime issuedAt;

  const DigitalReceipt({
    required this.id,
    required this.receiptNumber,
    required this.orderId,
    required this.storeName,
    required this.storePhone,
    required this.storeEmail,
    required this.consumerName,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 0,
    this.discount = 0,
    this.platformFee = 0,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.transactionReference,
    required this.issuedAt,
  });

  factory DigitalReceipt.fromMap(String id, Map<String, dynamic> map) => DigitalReceipt(
        id: id,
        receiptNumber: map['receiptNumber'] ?? '',
        orderId: map['orderId'] ?? '',
        storeName: map['storeName'] ?? '',
        storePhone: map['storePhone'] ?? '',
        storeEmail: map['storeEmail'] ?? '',
        consumerName: map['consumerName'] ?? '',
        items: ((map['items'] as List?) ?? const [])
            .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        subtotal: asDouble(map['subtotal']),
        deliveryFee: asDouble(map['deliveryFee']),
        discount: asDouble(map['discount']),
        platformFee: asDouble(map['platformFee']),
        total: asDouble(map['total']),
        paymentMethod: PaymentMethodX.fromName(map['paymentMethod'] ?? 'simulated'),
        paymentStatus: PaymentStatusX.fromName(map['paymentStatus'] ?? 'pending'),
        orderStatus: OrderStatusX.fromName(map['orderStatus'] ?? 'pendingPayment'),
        transactionReference: map['transactionReference'] ?? '',
        issuedAt: tsToDateOrNow(map['issuedAt']),
      );

  Map<String, dynamic> toMap() => {
        'receiptNumber': receiptNumber,
        'orderId': orderId,
        'storeName': storeName,
        'storePhone': storePhone,
        'storeEmail': storeEmail,
        'consumerName': consumerName,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'discount': discount,
        'platformFee': platformFee,
        'total': total,
        'paymentMethod': paymentMethod.name,
        'paymentStatus': paymentStatus.name,
        'orderStatus': orderStatus.name,
        'transactionReference': transactionReference,
        'issuedAt': issuedAt,
      };
}
