import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// `notifications` collection — the in-app notification center, the
/// primary record even when a push notification is also sent.
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? relatedRecordId;
  final String? relatedRecordType; // e.g. 'order', 'reservation', 'product'
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedRecordId,
    this.relatedRecordType,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) => AppNotification(
        id: id,
        userId: map['userId'] ?? '',
        type: NotificationTypeX.fromName(map['type'] ?? 'general'),
        title: map['title'] ?? '',
        message: map['message'] ?? '',
        relatedRecordId: map['relatedRecordId'],
        relatedRecordType: map['relatedRecordType'],
        read: map['read'] ?? false,
        createdAt: tsToDateOrNow(map['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type.name,
        'title': title,
        'message': message,
        'relatedRecordId': relatedRecordId,
        'relatedRecordType': relatedRecordType,
        'read': read,
      };
}
