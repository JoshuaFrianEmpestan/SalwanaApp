import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';

class AdminStats {
  final int totalUsers;
  final int activeMerchants;
  final int activeSuppliers;
  final int pendingMerchantVerifications;
  final int pendingSupplierVerifications;
  final int totalOrders;
  final double transactionVolume;
  final int reportedReviews;

  const AdminStats({
    required this.totalUsers,
    required this.activeMerchants,
    required this.activeSuppliers,
    required this.pendingMerchantVerifications,
    required this.pendingSupplierVerifications,
    required this.totalOrders,
    required this.transactionVolume,
    required this.reportedReviews,
  });

  int get pendingVerifications => pendingMerchantVerifications + pendingSupplierVerifications;
}

/// Read-only platform stats for the admin dashboard (§13). Uses Firestore
/// count() aggregation so this stays cheap even as collections grow —
/// no document bodies are downloaded just to display a number.
class AdminStatsRepository {
  final FirebaseFirestore _db;
  AdminStatsRepository(this._db);

  Future<int> _count(Query query) async => (await query.count().get()).count ?? 0;

  Future<AdminStats> computeStats() async {
    final results = await Future.wait([
      _count(_db.collection('users')),
      _count(_db.collection('stores').where('verificationStatus', isEqualTo: 'active')),
      _count(_db.collection('suppliers').where('verificationStatus', isEqualTo: 'active')),
      _count(_db.collection('users').where('role', isEqualTo: 'merchant').where('status', isEqualTo: 'pendingVerification')),
      _count(_db.collection('users').where('role', isEqualTo: 'supplier').where('status', isEqualTo: 'pendingVerification')),
      _count(_db.collection('orders')),
      _count(_db.collection('store_reviews').where('reported', isEqualTo: true)),
    ]);

    final transactionsSnap = await _db.collection('transactions').get();
    double volume = 0;
    for (final doc in transactionsSnap.docs) {
      if (doc.data()['reversed'] == true) continue;
      final amount = doc.data()['amount'];
      if (amount is num) volume += amount.toDouble();
    }

    return AdminStats(
      totalUsers: results[0],
      activeMerchants: results[1],
      activeSuppliers: results[2],
      pendingMerchantVerifications: results[3],
      pendingSupplierVerifications: results[4],
      totalOrders: results[5],
      transactionVolume: volume,
      reportedReviews: results[6],
    );
  }
}

final adminStatsRepositoryProvider = Provider<AdminStatsRepository>((ref) {
  return AdminStatsRepository(ref.watch(firestoreProvider));
});
