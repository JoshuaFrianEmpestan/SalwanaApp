import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/enums.dart';
import '../core/utils/firestore_helpers.dart';

/// Mirrors the `users` collection — the single source of truth for role,
/// account status, and identity shared by all four dashboards.
class AppUser {
  final String id;
  final String email;
  final bool emailVerified;
  final String fullName;
  final String? phone;
  final UserRole role;
  final AccountStatus status;
  final String? statusReason;
  final String? photoUrl;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool notificationsEnabled;

  const AppUser({
    required this.id,
    required this.email,
    required this.emailVerified,
    required this.fullName,
    this.phone,
    required this.role,
    required this.status,
    this.statusReason,
    this.photoUrl,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
    this.notificationsEnabled = true,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> map) => AppUser(
        id: id,
        email: map['email'] ?? '',
        emailVerified: map['emailVerified'] ?? false,
        fullName: map['fullName'] ?? '',
        phone: map['phone'],
        role: UserRoleX.fromName(map['role'] ?? 'consumer'),
        status: AccountStatusX.fromName(map['status'] ?? 'active'),
        statusReason: map['statusReason'],
        photoUrl: map['photoUrl'],
        fcmToken: map['fcmToken'],
        createdAt: tsToDateOrNow(map['createdAt']),
        updatedAt: tsToDateOrNow(map['updatedAt']),
        notificationsEnabled: map['notificationsEnabled'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'emailVerified': emailVerified,
        'fullName': fullName,
        'phone': phone,
        'role': role.name,
        'status': status.name,
        'statusReason': statusReason,
        'photoUrl': photoUrl,
        'fcmToken': fcmToken,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'notificationsEnabled': notificationsEnabled,
      };

  bool get isActive => status == AccountStatus.active;
}
