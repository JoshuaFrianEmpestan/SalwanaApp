import '../core/utils/firestore_helpers.dart';

/// `audit_logs` collection — append-only. Written by Cloud Functions
/// whenever an important/administrative change happens (verification
/// decisions, suspensions, manual admin corrections to merchant data,
/// status overrides, etc). Never editable from the client.
class AuditLog {
  final String id;
  final String actorUserId;
  final String actorName;
  final String actorRole;
  final String action;
  final String targetType;
  final String targetId;
  final String reason;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.actorUserId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.metadata,
    required this.createdAt,
  });

  factory AuditLog.fromMap(String id, Map<String, dynamic> map) => AuditLog(
        id: id,
        actorUserId: map['actorUserId'] ?? '',
        actorName: map['actorName'] ?? '',
        actorRole: map['actorRole'] ?? '',
        action: map['action'] ?? '',
        targetType: map['targetType'] ?? '',
        targetId: map['targetId'] ?? '',
        reason: map['reason'] ?? '',
        metadata: map['metadata'] == null ? null : Map<String, dynamic>.from(map['metadata']),
        createdAt: tsToDateOrNow(map['createdAt']),
      );
}
