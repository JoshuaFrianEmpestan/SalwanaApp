import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `expenses` collection — merchant operating expenses.
class Expense {
  final String id;
  final String merchantId;
  final String storeId;
  final ExpenseCategory category;
  final String description;
  final double amount;
  final DateTime incurredAt;
  final String recordedByUserId;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.merchantId,
    required this.storeId,
    required this.category,
    required this.description,
    required this.amount,
    required this.incurredAt,
    required this.recordedByUserId,
    required this.createdAt,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> map) => Expense(
        id: id,
        merchantId: map['merchantId'] ?? '',
        storeId: map['storeId'] ?? '',
        category: ExpenseCategoryX.fromName(map['category'] ?? 'other'),
        description: map['description'] ?? '',
        amount: asDouble(map['amount']),
        incurredAt: tsToDateOrNow(map['incurredAt']),
        recordedByUserId: map['recordedByUserId'] ?? '',
        createdAt: tsToDateOrNow(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'merchantId': merchantId,
        'storeId': storeId,
        'category': category.name,
        'description': description,
        'amount': amount,
        'incurredAt': incurredAt,
        'recordedByUserId': recordedByUserId,
      };
}
