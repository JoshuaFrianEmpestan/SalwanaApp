import '../core/utils/firestore_helpers.dart';

/// `capital_entries` collection — initial or additional capital injections.
class CapitalEntry {
  final String id;
  final String merchantId;
  final String storeId;
  final bool isInitial;
  final double amount;
  final String source;
  final String? notes;
  final DateTime recordedAt;
  final DateTime createdAt;

  const CapitalEntry({
    required this.id,
    required this.merchantId,
    required this.storeId,
    required this.isInitial,
    required this.amount,
    required this.source,
    this.notes,
    required this.recordedAt,
    required this.createdAt,
  });

  factory CapitalEntry.fromMap(String id, Map<String, dynamic> map) => CapitalEntry(
        id: id,
        merchantId: map['merchantId'] ?? '',
        storeId: map['storeId'] ?? '',
        isInitial: map['isInitial'] ?? false,
        amount: asDouble(map['amount']),
        source: map['source'] ?? '',
        notes: map['notes'],
        recordedAt: tsToDateOrNow(map['recordedAt']),
        createdAt: tsToDateOrNow(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'merchantId': merchantId,
        'storeId': storeId,
        'isInitial': isInitial,
        'amount': amount,
        'source': source,
        'notes': notes,
        'recordedAt': recordedAt,
      };
}
