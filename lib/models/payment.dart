import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `payments` collection. `idempotencyKey` (set client-side, unique per
/// checkout attempt) is enforced unique by the processPayment Cloud
/// Function to prevent duplicate charges on retry/double-tap.
class Payment {
  final String id;
  final String orderId;
  final String checkoutGroupId;
  final String consumerId;
  final String merchantId;
  final PaymentMethod method;
  final PaymentStatus status;
  final double amount;
  final String idempotencyKey;
  final String? providerReference;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.checkoutGroupId,
    required this.consumerId,
    required this.merchantId,
    required this.method,
    required this.status,
    required this.amount,
    required this.idempotencyKey,
    this.providerReference,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.fromMap(String id, Map<String, dynamic> map) => Payment(
        id: id,
        orderId: map['orderId'] ?? '',
        checkoutGroupId: map['checkoutGroupId'] ?? '',
        consumerId: map['consumerId'] ?? '',
        merchantId: map['merchantId'] ?? '',
        method: PaymentMethodX.fromName(map['method'] ?? 'simulated'),
        status: PaymentStatusX.fromName(map['status'] ?? 'pending'),
        amount: asDouble(map['amount']),
        idempotencyKey: map['idempotencyKey'] ?? '',
        providerReference: map['providerReference'],
        failureReason: map['failureReason'],
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'checkoutGroupId': checkoutGroupId,
        'consumerId': consumerId,
        'merchantId': merchantId,
        'method': method.name,
        'status': status.name,
        'amount': amount,
        'idempotencyKey': idempotencyKey,
        'providerReference': providerReference,
        'failureReason': failureReason,
      };
}
