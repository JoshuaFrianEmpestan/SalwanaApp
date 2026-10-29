import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/store_review.dart';

class ReviewException implements Exception {
  final String message;
  ReviewException(this.message);
  @override
  String toString() => message;
}

class ReviewRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  ReviewRepository(this._db, this._functions);

  Future<void> submit({required String orderId, required int rating, required String feedback}) async {
    try {
      await _functions.httpsCallable('submitStoreReview').call<Map<String, dynamic>>({
        'orderId': orderId,
        'rating': rating,
        'feedback': feedback,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ReviewException(e.message ?? 'Could not submit review.');
    }
  }

  Future<void> edit({required String reviewId, required int rating, required String feedback}) async {
    try {
      await _functions.httpsCallable('editStoreReview').call<Map<String, dynamic>>({
        'reviewId': reviewId,
        'rating': rating,
        'feedback': feedback,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ReviewException(e.message ?? 'Could not update review.');
    }
  }

  Future<void> respond({required String reviewId, required String response}) async {
    try {
      await _functions.httpsCallable('respondToReview').call<Map<String, dynamic>>({
        'reviewId': reviewId,
        'response': response,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ReviewException(e.message ?? 'Could not respond to review.');
    }
  }

  Future<void> report({required String reviewId, required String reason}) async {
    try {
      await _functions.httpsCallable('reportReview').call<Map<String, dynamic>>({
        'reviewId': reviewId,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ReviewException(e.message ?? 'Could not report review.');
    }
  }

  Stream<List<StoreReview>> watchStoreReviews(String storeId) {
    return _db
        .collection('store_reviews')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => StoreReview.fromMap(d.id, d.data())).where((r) => !r.hidden).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<StoreReview?> watchReview(String orderId) {
    return _db.collection('store_reviews').doc(orderId).snapshots().map((d) => d.exists ? StoreReview.fromMap(d.id, d.data()!) : null);
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(firestoreProvider), ref.watch(firebaseFunctionsProvider));
});

final storeReviewsProvider = StreamProvider.family<List<StoreReview>, String>((ref, storeId) {
  return ref.watch(reviewRepositoryProvider).watchStoreReviews(storeId);
});

final reviewByOrderProvider = StreamProvider.family<StoreReview?, String>((ref, orderId) {
  return ref.watch(reviewRepositoryProvider).watchReview(orderId);
});
