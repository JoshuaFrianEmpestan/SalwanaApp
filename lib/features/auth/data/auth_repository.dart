import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../models/app_user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthRepository(this._auth, this._db);

  User? get currentUser => _auth.currentUser;

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  /// Registers a new user and creates their `users/{uid}` profile. Merchant
  /// and supplier accounts start in `pendingVerification` until an admin
  /// approves them (§4 Administrator, §2 onboarding step 7); consumers are
  /// active immediately once they verify their email.
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    try {
      if (role == UserRole.admin) {
        throw AuthException('Administrator accounts cannot be created through registration.');
      }
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final uid = credential.user!.uid;

      final initialStatus =
          role == UserRole.consumer ? AccountStatus.active : AccountStatus.pendingVerification;

      final user = AppUser(
        id: uid,
        email: email,
        emailVerified: false,
        fullName: fullName,
        phone: phone,
        role: role,
        status: initialStatus,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _db.collection('users').doc(uid).set(user.toMap());
      await credential.user!.updateDisplayName(fullName);
      await credential.user!.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  /// Clears the FCM token before signing out — must happen first, since
  /// writing to the user's own doc requires still being authenticated as
  /// them (§20 ownership rules). Best-effort: a failure here never blocks
  /// sign-out itself.
  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reloads the Firebase Auth user and syncs `emailVerified` into
  /// Firestore so it's visible to admins and other server-side checks.
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await _db.collection('users').doc(refreshed.uid).update({
        'emailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
    return false;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider));
});
