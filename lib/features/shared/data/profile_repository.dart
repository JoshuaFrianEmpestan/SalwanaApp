import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';

class ProfileException implements Exception {
  final String message;
  ProfileException(this.message);
  @override
  String toString() => message;
}

/// Own-account edits shared by every role (§1 follow-up) — profile fields,
/// notification toggle, and password change. Kept separate from the
/// role-specific store/supplier profile repositories, which manage the
/// business-facing profile, not the person's own account.
class ProfileRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  ProfileRepository(this._db, this._auth);

  Future<void> updateProfile(String uid, {required String fullName, required String phone, String? photoUrl}) async {
    await _db.collection('users').doc(uid).update({
      'fullName': fullName,
      'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _auth.currentUser?.updateDisplayName(fullName);
  }

  Future<void> setNotificationsEnabled(String uid, bool enabled) async {
    await _db.collection('users').doc(uid).update({'notificationsEnabled': enabled, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw ProfileException('You must be signed in.');
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw ProfileException(switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Current password is incorrect.',
        'weak-password' => 'New password is too weak.',
        _ => e.message ?? 'Could not change password.',
      });
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider));
});
