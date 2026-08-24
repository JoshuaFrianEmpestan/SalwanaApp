import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/reservation.dart';

class ReservationException implements Exception {
  final String message;
  ReservationException(this.message);
  @override
  String toString() => message;
}

/// Client for the reservation Cloud Functions plus the read-side streams
/// consumers/merchants use to watch their own reservations (§4).
class ReservationRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  ReservationRepository(this._functions, this._db);

  Future<String> createReservation({
    required String productId,
    required int quantity,
    required FulfillmentType fulfillmentType,
    required DateTime scheduledFor,
    String? deliveryAddressText,
    String? notes,
  }) async {
    try {
      final result = await _functions.httpsCallable('createReservation').call<Map<String, dynamic>>({
        'productId': productId,
        'quantity': quantity,
        'fulfillmentType': fulfillmentType.name,
        'scheduledForIso': scheduledFor.toIso8601String(),
        'deliveryAddressText': deliveryAddressText,
        'notes': notes,
      });
      return result.data['reservationId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw ReservationException(e.message ?? 'Could not create reservation. Please try again.');
    }
  }

  Future<void> _updateStatus(String reservationId, String action, {String? reason}) async {
    try {
      await _functions.httpsCallable('updateReservationStatus').call<Map<String, dynamic>>({
        'reservationId': reservationId,
        'action': action,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ReservationException(e.message ?? 'Could not update this reservation.');
    }
  }

  Future<void> approve(String reservationId) => _updateStatus(reservationId, 'approve');
  Future<void> reject(String reservationId, String reason) => _updateStatus(reservationId, 'reject', reason: reason);
  Future<void> markPreparing(String reservationId) => _updateStatus(reservationId, 'preparing');
  Future<void> markReadyForPickup(String reservationId) => _updateStatus(reservationId, 'readyForPickup');
  Future<void> markOutForDelivery(String reservationId) => _updateStatus(reservationId, 'outForDelivery');
  Future<void> markCompleted(String reservationId) => _updateStatus(reservationId, 'completed');
  Future<void> cancel(String reservationId) => _updateStatus(reservationId, 'cancel');

  Stream<List<Reservation>> watchConsumerReservations(String consumerId) {
    return _db
        .collection('reservations')
        .where('consumerId', isEqualTo: consumerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Reservation.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Reservation>> watchMerchantReservations(String merchantId) {
    return _db
        .collection('reservations')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Reservation.fromMap(d.id, d.data())).toList());
  }

  Stream<Reservation?> watchReservation(String id) {
    return _db.collection('reservations').doc(id).snapshots().map((d) => d.exists ? Reservation.fromMap(d.id, d.data()!) : null);
  }
}

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepository(ref.watch(firebaseFunctionsProvider), ref.watch(firestoreProvider));
});

final consumerReservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(reservationRepositoryProvider).watchConsumerReservations(user.id);
});

final merchantReservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(reservationRepositoryProvider).watchMerchantReservations(user.id);
});

final reservationDetailProvider = StreamProvider.family<Reservation?, String>((ref, id) {
  return ref.watch(reservationRepositoryProvider).watchReservation(id);
});
