import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/user/user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Remembers when we last auto-sent a reset email to each address,
  // so repeated wrong passwords don't spam the inbox.
  final Map<String, DateTime> _lastResetAt = {};

  // Stream that tells the app whether someone is logged in, in real time
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  //Why return String? instead of throwing: it's a simpler pattern for your login screen — no try/catch needed there, just check if (error != null) and show it.

  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'email': email,
            'displayName': email.split('@').first, // editable later in Profile
            'coupleId': null,
          });

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign up failed';
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      return 'Enter your email and password';
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: trimmed,
        password: password,
      );
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        // Badly formatted email: no reset email, the address can't be valid.
        case 'invalid-email':
          return 'That email address looks invalid';

        // Wrong password or no such account (Firebase can't tell us which
        // while email enumeration protection is on). Send the reset email.
        case 'invalid-credential':
        case 'wrong-password':
          await _sendResetWithCooldown(trimmed);
          return 'The supplied auth credential is incorrect, malformed or has expired.\n'
              'If that email has an account, we sent a reset link to it.';

        // Only appears if enumeration protection is turned off.
        case 'user-not-found':
          return 'No account found for that email';

        case 'user-disabled':
          return 'This account has been disabled';
        case 'too-many-requests':
          return 'Too many attempts. Wait a bit, or use the reset link.';
        case 'network-request-failed':
          return 'No connection. Check your internet and try again';
        default:
          return e.message ?? 'Sign in failed';
      }
    }
  }

  Future<void> _sendResetWithCooldown(String email) async {
    final last = _lastResetAt[email];
    final recentlySent =
        last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2);
    if (recentlySent) return;
    _lastResetAt[email] = DateTime.now();
    await sendPasswordReset(email);
  }

  Future<String?> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return 'Enter your email first';
    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') return 'That email looks invalid';
      return e.message ?? 'Failed to send reset email';
    }
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await UserService().updateFcmToken(uid, '');
      // empty string signals "no active token" — or use FieldValue.delete() if you prefer removing the field entirely
    }
    await _auth.signOut();
    NotificationService.reset();
  }
}
