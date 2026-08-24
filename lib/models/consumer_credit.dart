import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `consumer_credit_accounts` collection — merchant-approved store-credit
/// arrangement for a specific consumer, optionally tied to an order.
/// This is record-tracking only; Salwana is not a lender.
class ConsumerCreditAccount {
  final String id;
  final String merchantId;
  final String storeId;
  final String consumerId;
  final String consumerName;
  final String? relatedOrderId;
  final double originalAmount;
  final double amountPaid;
  final DateTime dueDate;
  final String? paymentSchedule;
  final String? notes;
  final CreditStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConsumerCreditAccount({
    required this.id,
    required this.merchantId,
    required this.storeId,
    required this.consumerId,
    required this.consumerName,
    this.relatedOrderId,
    required this.originalAmount,
    this.amountPaid = 0,
    required this.dueDate,
    this.paymentSchedule,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  double get remainingBalance => (originalAmount - amountPaid).clamp(0, double.infinity);

  factory ConsumerCreditAccount.fromMap(String id, Map<String, dynamic> map) => ConsumerCreditAccount(
        id: id,
        merchantId: map['merchantId'] ?? '',
        storeId: map['storeId'] ?? '',
        consumerId: map['consumerId'] ?? '',
        consumerName: map['consumerName'] ?? '',
        relatedOrderId: map['relatedOrderId'],
        originalAmount: asDouble(map['originalAmount']),
        amountPaid: asDouble(map['amountPaid']),
        dueDate: tsToDateOrNow(map['dueDate']),
        paymentSchedule: map['paymentSchedule'],
        notes: map['notes'],
        status: CreditStatusX.fromName(map['status'] ?? 'active'),
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'merchantId': merchantId,
        'storeId': storeId,
        'consumerId': consumerId,
        'consumerName': consumerName,
        'relatedOrderId': relatedOrderId,
        'originalAmount': originalAmount,
        'amountPaid': amountPaid,
        'dueDate': dueDate,
        'paymentSchedule': paymentSchedule,
        'notes': notes,
        'status': status.name,
      };
}

/// `consumer_credit_accounts/{id}/payments` subcollection.
class ConsumerCreditPayment {
  final String id;
  final double amount;
  final DateTime paidAt;
  final String recordedByUserId;
  final String? notes;

  const ConsumerCreditPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.recordedByUserId,
    this.notes,
  });

  factory ConsumerCreditPayment.fromMap(String id, Map<String, dynamic> map) => ConsumerCreditPayment(
        id: id,
        amount: asDouble(map['amount']),
        paidAt: tsToDateOrNow(map['paidAt']),
        recordedByUserId: map['recordedByUserId'] ?? '',
        notes: map['notes'],
      );

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'paidAt': paidAt,
        'recordedByUserId': recordedByUserId,
        'notes': notes,
      };
}
