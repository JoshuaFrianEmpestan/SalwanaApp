import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';

/// Creates the merchant `stores` doc / supplier `suppliers` doc right after
/// registration, both starting at `pendingVerification` until an admin
/// approves them (§2 step 7, §4 Administrator verification).
class OnboardingRepository {
  final FirebaseFirestore _db;
  OnboardingRepository(this._db);

  Future<void> submitMerchantStore({
    required String merchantId,
    required String storeName,
    required String category,
    required String phone,
    required String email,
    required String addressLine,
    required String city,
    required String description,
  }) async {
    await _db.collection('stores').doc(merchantId).set({
      'merchantId': merchantId,
      'name': storeName,
      'description': description,
      'category': category,
      'phone': phone,
      'email': email,
      'addressLine': addressLine,
      'city': city,
      'verificationStatus': AccountStatus.pendingVerification.name,
      'barcodeEnabled': false,
      'reservationExpirationMinutes': 120,
      'averageRating': 0,
      'ratingCount': 0,
      'planTier': SubscriptionPlanTier.free.name,
      'isOpen': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitSupplierProfile({
    required String supplierId,
    required String companyName,
    required String contactName,
    required String phone,
    required String email,
    required String address,
  }) async {
    await _db.collection('suppliers').doc(supplierId).set({
      'userId': supplierId,
      'companyName': companyName,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'suppliedCategories': <String>[],
      'verificationStatus': AccountStatus.pendingVerification.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(firestoreProvider));
});
