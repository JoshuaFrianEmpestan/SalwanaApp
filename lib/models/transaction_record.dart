import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `transactions` collection — the normalized ledger entry finance
/// tracking, dashboards, and reports (modules 10/13/15) read from, so
/// those modules never re-derive revenue from raw order documents.
/// Doc id == orderId, written once by the Cloud Function that settles
/// the order (COD confirmation or successful online payment).
class TransactionRecord {
  final String id;
  final String orderId;
  final String storeId;
  final String merchantId;
  final String consumerId;
  final double amount;
  final double subtotal;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;

  const TransactionRecord({
    required this.id,
    required this.orderId,
    required this.storeId,
    required this.merchantId,
    required this.consumerId,
    required this.amount,
    required this.subtotal,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory TransactionRecord.fromMap(String id, Map<String, dynamic> map) => TransactionRecord(
        id: id,
        orderId: map['orderId'] ?? '',
        storeId: map['storeId'] ?? '',
        merchantId: map['merchantId'] ?? '',
        consumerId: map['consumerId'] ?? '',
        amount: asDouble(map['amount']),
        subtotal: asDouble(map['subtotal']),
        paymentMethod: PaymentMethodX.fromName(map['paymentMethod'] ?? 'simulated'),
        createdAt: tsToDateOrNow(map['createdAt']),
      );
}
