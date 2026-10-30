import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/subscription.dart';

class SubscriptionException implements Exception {
  final String message;
  SubscriptionException(this.message);
  @override
  String toString() => message;
}

const _freePlanId = 'free';
const _premiumPlanId = 'premium';

/// Subscription plans + a merchant's current subscription (§14). Plan docs
/// use fixed ids (`free`/`premium`) so there's always exactly one of each,
/// and are seeded on first read if the admin hasn't configured them yet —
/// a merchant should never see "no plan available" on a fresh install.
class SubscriptionRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  SubscriptionRepository(this._db, this._auth);

  CollectionReference<Map<String, dynamic>> get _plans => _db.collection('subscription_plans');

  Future<void> ensureDefaultPlans() async {
    final freeSnap = await _plans.doc(_freePlanId).get();
    if (!freeSnap.exists) {
      await _plans.doc(_freePlanId).set(const SubscriptionPlan(
            id: _freePlanId,
            tier: SubscriptionPlanTier.free,
            name: 'Free',
            monthlyPrice: 0,
            productLimit: 20,
            transactionHistoryDays: 90,
          ).toMap());
    }
    final premiumSnap = await _plans.doc(_premiumPlanId).get();
    if (!premiumSnap.exists) {
      await _plans.doc(_premiumPlanId).set(const SubscriptionPlan(
            id: _premiumPlanId,
            tier: SubscriptionPlanTier.premium,
            name: 'Premium',
            monthlyPrice: 499,
            productLimit: -1,
            advancedAnalytics: true,
            pdfExcelReports: true,
            lowStockAutomation: true,
            supplierManagement: true,
            barcodeFeatures: true,
            transactionHistoryDays: -1,
            prioritySupport: true,
          ).toMap());
    }
  }

  Stream<List<SubscriptionPlan>> watchPlans() {
    return _plans.snapshots().map((s) => s.docs.map((d) => SubscriptionPlan.fromMap(d.id, d.data())).toList());
  }

  Future<void> updatePlan(String planId, Map<String, dynamic> patch) async {
    await _plans.doc(planId).update(patch);
  }

  Stream<MerchantSubscription?> watchMySubscription(String merchantId) {
    return _db
        .collection('subscriptions')
        .doc(merchantId)
        .snapshots()
        .map((d) => d.exists ? MerchantSubscription.fromMap(d.id, d.data()!) : null);
  }

  Future<void> subscribeToPremium() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw SubscriptionException('Not signed in.');
      final token = await user.getIdToken();
      final resp = await http.post(
        Uri.parse('https://salwanaapp.onrender.com/subscribeToPremium'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode >= 400) {
        final body = jsonDecode(resp.body);
        throw SubscriptionException(body['error'] ?? 'Could not activate Premium. Please try again.');
      }
    } catch (e) {
      if (e is SubscriptionException) rethrow;
      throw SubscriptionException(e.toString());
    }
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider));
});

final subscriptionPlansProvider = StreamProvider<List<SubscriptionPlan>>((ref) {
  ref.watch(subscriptionRepositoryProvider).ensureDefaultPlans();
  return ref.watch(subscriptionRepositoryProvider).watchPlans();
});

final mySubscriptionProvider = StreamProvider<MerchantSubscription?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(subscriptionRepositoryProvider).watchMySubscription(user.id);
});

/// The plan actually in effect right now — Free if there's no active
/// premium subscription, which is also what a lapsed/expired premium
/// subscription falls back to (§14: expiry never deletes data, it only
/// restricts premium-only actions).
final effectivePlanProvider = Provider<SubscriptionPlan?>((ref) {
  final plans = ref.watch(subscriptionPlansProvider).valueOrNull;
  final subscription = ref.watch(mySubscriptionProvider).valueOrNull;
  if (plans == null || plans.isEmpty) return null;
  final isPremiumActive = subscription?.isActive ?? false;
  return plans.firstWhere(
    (p) => p.tier == (isPremiumActive ? SubscriptionPlanTier.premium : SubscriptionPlanTier.free),
    orElse: () => plans.first,
  );
});
