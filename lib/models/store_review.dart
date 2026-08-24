import '../core/utils/firestore_helpers.dart';

/// `store_reviews` collection. `orderId` enforces the "one review per
/// completed order" rule via a Firestore unique-doc-id trick (the review
/// doc id is set to the orderId itself).
class StoreReview {
  final String id;
  final String storeId;
  final String consumerId;
  final String consumerName;
  final String orderId;
  final int rating;
  final String feedback;
  final String? merchantResponse;
  final DateTime? merchantResponseAt;
  final bool reported;
  final String? reportReason;
  final bool hidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoreReview({
    required this.id,
    required this.storeId,
    required this.consumerId,
    required this.consumerName,
    required this.orderId,
    required this.rating,
    required this.feedback,
    this.merchantResponse,
    this.merchantResponseAt,
    this.reported = false,
    this.reportReason,
    this.hidden = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isEditable => DateTime.now().difference(createdAt).inDays < 7;

  factory StoreReview.fromMap(String id, Map<String, dynamic> map) => StoreReview(
        id: id,
        storeId: map['storeId'] ?? '',
        consumerId: map['consumerId'] ?? '',
        consumerName: map['consumerName'] ?? '',
        orderId: map['orderId'] ?? '',
        rating: asInt(map['rating']),
        feedback: map['feedback'] ?? '',
        merchantResponse: map['merchantResponse'],
        merchantResponseAt: tsToDate(map['merchantResponseAt']),
        reported: map['reported'] ?? false,
        reportReason: map['reportReason'],
        hidden: map['hidden'] ?? false,
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'consumerId': consumerId,
        'consumerName': consumerName,
        'orderId': orderId,
        'rating': rating,
        'feedback': feedback,
        'merchantResponse': merchantResponse,
        'merchantResponseAt': merchantResponseAt,
        'reported': reported,
        'reportReason': reportReason,
        'hidden': hidden,
      };
}
