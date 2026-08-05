import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../core/failure.dart';
import '../core/result.dart';
import '../models/app_user.dart';

/// Owns all authentication and user-profile logic. The UI talks only to this
/// repository, never to FirebaseAuth or Firestore directly, so the Firebase SDK
/// stays an implementation detail that is easy to mock in tests.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Emits the current [AppUser] (or null) whenever auth state changes.
  Stream<AppUser?> authState() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _hydrate(user);
    });
  }

  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AppUser(uid: user.uid, email: user.email ?? '');
  }

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = await _hydrate(credential.user!);
      return Success(user);
    } on FirebaseAuthException catch (e) {
      return ResultFailure(AuthFailure(_mapAuthError(e), code: e.code));
    } catch (e) {
      return ResultFailure(AuthFailure('Sign in failed: $e'));
    }
  }

  Future<Result<AppUser>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final firebaseUser = credential.user!;
      if (displayName != null && displayName.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(displayName.trim());
      }
      final user = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? email.trim(),
        displayName: displayName?.trim(),
        createdAt: DateTime.now().toUtc(),
      );
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(user.toJson());
      return Success(user);
    } on FirebaseAuthException catch (e) {
      return ResultFailure(AuthFailure(_mapAuthError(e), code: e.code));
    } catch (e) {
      return ResultFailure(AuthFailure('Registration failed: $e'));
    }
  }

  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Success(null);
    } on FirebaseAuthException catch (e) {
      return ResultFailure(AuthFailure(_mapAuthError(e), code: e.code));
    }
  }

  Future<Result<AppUser>> updatePreferShade(bool preferShade) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const ResultFailure(AuthFailure('Not signed in.'));
    }
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set({'preferShade': preferShade}, SetOptions(merge: true));
      final user = await _hydrate(_auth.currentUser!);
      return Success(user.copyWith(preferShade: preferShade));
    } catch (e) {
      return ResultFailure(DatabaseFailure('Could not save preference: $e'));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppUser> _hydrate(User user) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .get();
    if (doc.exists && doc.data() != null) {
      return AppUser.fromJson(user.uid, doc.data()!);
    }
    // First login without a profile doc: create a minimal one.
    final fresh = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: DateTime.now().toUtc(),
    );
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(fresh.toJson(), SetOptions(merge: true));
    return fresh;
  }

  String _mapAuthError(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'That email address looks invalid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists for that email.',
      'weak-password' => 'Please choose a stronger password (6+ characters).',
      'network-request-failed' => 'Network error. Check your connection.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      _ => e.message ?? 'Authentication error.',
    };
  }
}
