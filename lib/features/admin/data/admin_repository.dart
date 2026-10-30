import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';
import '../../../models/application_settings.dart';
import '../../../models/audit_log.dart';
import '../../../models/order.dart' as model;
import '../../../models/product_category.dart';
import '../../../models/store_review.dart';

class AdminActionException implements Exception {
  final String message;
  AdminActionException(this.message);
  @override
  String toString() => message;
}

/// Everything the admin panel needs (§4, §16) — user/account moderation
/// runs through Cloud Functions (audit-logged, see functions/src/admin/*),
/// while lower-stakes config (categories, settings) is a direct write
/// under rules that already restrict it to isAdmin().
class AdminRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  AdminRepository(this._db, this._functions);

  Stream<List<AppUser>> watchUsers() {
    return _db.collection('users').orderBy('createdAt', descending: true).snapshots().map(
          (s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<AppUser?> watchUser(String id) {
    return _db.collection('users').doc(id).snapshots().map((d) => d.exists ? AppUser.fromMap(d.id, d.data()!) : null);
  }

  Future<void> verifyAccount({required String targetUserId, required String targetType, required bool approve, String? reason}) async {
    try {
      await _functions.httpsCallable('verifyAccount').call<Map<String, dynamic>>({
        'targetUserId': targetUserId,
        'targetType': targetType,
        'decision': approve ? 'approve' : 'reject',
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminActionException(e.message ?? 'Could not verify account.');
    }
  }

  Future<void> setAccountStatus({required String targetUserId, required String status, required String reason}) async {
    try {
      await _functions.httpsCallable('setAccountStatus').call<Map<String, dynamic>>({
        'targetUserId': targetUserId,
        'status': status,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminActionException(e.message ?? 'Could not update account status.');
    }
  }

  Future<void> moderateReview({required String reviewId, required bool hidden, required String reason}) async {
    try {
      await _functions.httpsCallable('moderateReview').call<Map<String, dynamic>>({
        'reviewId': reviewId,
        'hidden': hidden,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AdminActionException(e.message ?? 'Could not moderate review.');
    }
  }

  Stream<List<StoreReview>> watchReportedReviews() {
    return _db.collection('store_reviews').where('reported', isEqualTo: true).snapshots().map(
          (s) => s.docs.map((d) => StoreReview.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<model.Order>> watchAllOrders() {
    return _db.collection('orders').orderBy('createdAt', descending: true).limit(200).snapshots().map(
          (s) => s.docs.map((d) => model.Order.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<ProductCategory>> watchCategories() {
    return _db.collection('product_categories').orderBy('name').snapshots().map(
          (s) => s.docs.map((d) => ProductCategory.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> addCategory(String name) async {
    await _db.collection('product_categories').add({'name': name, 'active': true, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> setCategoryActive(String id, bool active) async {
    await _db.collection('product_categories').doc(id).update({'active': active});
  }

  Stream<ApplicationSettings> watchSettings() {
    return _db.collection('application_settings').doc('global').snapshots().map(
          (d) => d.exists ? ApplicationSettings.fromMap(d.data()!) : const ApplicationSettings(),
        );
  }

  Future<void> updateSettings(Map<String, dynamic> patch) async {
    await _db.collection('application_settings').doc('global').set(patch, SetOptions(merge: true));
  }

  Stream<List<AuditLog>> watchAuditLogs() {
    return _db.collection('audit_logs').orderBy('createdAt', descending: true).limit(100).snapshots().map(
          (s) => s.docs.map((d) => AuditLog.fromMap(d.id, d.data())).toList(),
        );
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

final allUsersProvider = StreamProvider<List<AppUser>>((ref) => ref.watch(adminRepositoryProvider).watchUsers());
final userByIdProvider = StreamProvider.family<AppUser?, String>((ref, id) => ref.watch(adminRepositoryProvider).watchUser(id));
final reportedReviewsProvider = StreamProvider<List<StoreReview>>((ref) => ref.watch(adminRepositoryProvider).watchReportedReviews());
final allOrdersProvider = StreamProvider<List<model.Order>>((ref) => ref.watch(adminRepositoryProvider).watchAllOrders());
final productCategoriesProvider = StreamProvider<List<ProductCategory>>((ref) => ref.watch(adminRepositoryProvider).watchCategories());
final applicationSettingsProvider = StreamProvider<ApplicationSettings>((ref) => ref.watch(adminRepositoryProvider).watchSettings());
final auditLogsProvider = StreamProvider<List<AuditLog>>((ref) => ref.watch(adminRepositoryProvider).watchAuditLogs());
