import '../core/utils/firestore_helpers.dart';

/// `merchant_loans` collection.
class MerchantLoan {
  final String id;
  final String merchantId;
  final String storeId;
  final String lender;
  final double principal;
  final double interestRate; // percent, flat over the loan term (simplified)
  final double totalPaid;
  final DateTime dueDate;
  final String? notes;
  final bool isCancelled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MerchantLoan({
    required this.id,
    required this.merchantId,
    required this.storeId,
    required this.lender,
    required this.principal,
    this.interestRate = 0,
    this.totalPaid = 0,
    required this.dueDate,
    this.notes,
    this.isCancelled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  double get interestAmount => principal * (interestRate / 100);
  double get totalOwed => principal + interestAmount;
  double get remainingBalance => (totalOwed - totalPaid).clamp(0, double.infinity);
  bool get isFullyPaid => remainingBalance <= 0;
  bool get isOverdue => !isFullyPaid && !isCancelled && DateTime.now().isAfter(dueDate);

  factory MerchantLoan.fromMap(String id, Map<String, dynamic> map) => MerchantLoan(
        id: id,
        merchantId: map['merchantId'] ?? '',
        storeId: map['storeId'] ?? '',
        lender: map['lender'] ?? '',
        principal: asDouble(map['principal']),
        interestRate: asDouble(map['interestRate']),
        totalPaid: asDouble(map['totalPaid']),
        dueDate: tsToDateOrNow(map['dueDate']),
        notes: map['notes'],
        isCancelled: map['isCancelled'] ?? false,
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'merchantId': merchantId,
        'storeId': storeId,
        'lender': lender,
        'principal': principal,
        'interestRate': interestRate,
        'totalPaid': totalPaid,
        'dueDate': dueDate,
        'notes': notes,
        'isCancelled': isCancelled,
      };
}

/// `merchant_loans/{loanId}/payments` subcollection.
class MerchantLoanPayment {
  final String id;
  final double amount;
  final DateTime paidAt;
  final String? notes;
  final String recordedByUserId;

  const MerchantLoanPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    this.notes,
    required this.recordedByUserId,
  });

  factory MerchantLoanPayment.fromMap(String id, Map<String, dynamic> map) => MerchantLoanPayment(
        id: id,
        amount: asDouble(map['amount']),
        paidAt: tsToDateOrNow(map['paidAt']),
        notes: map['notes'],
        recordedByUserId: map['recordedByUserId'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'paidAt': paidAt,
        'notes': notes,
        'recordedByUserId': recordedByUserId,
      };
}
