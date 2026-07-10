import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<String> getDisplayName(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final name = doc.data()?['displayName'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final email = doc.data()?['email'] as String? ?? '';
    return email.isNotEmpty ? email.split('@').first : 'Partner';
  }

  // Live stream version — useful so Message Board updates instantly if name changes
  Stream<String> watchDisplayName(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final name = doc.data()?['displayName'] as String?;
      if (name != null && name.trim().isNotEmpty) return name;
      final email = doc.data()?['email'] as String? ?? '';
      return email.isNotEmpty ? email.split('@').first : 'Partner';
    });
  }

  Future<String?> updateDisplayName(String uid, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return 'Name cannot be empty';
    try {
      await _firestore.collection('users').doc(uid).set({
        'displayName': trimmed,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return 'Failed to update name';
    }
  }

  // Firebase requires a recent login before sensitive actions like password change
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return 'Not logged in';

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Current password is incorrect';
      }
      return e.message ?? 'Failed to change password';
    }
  }

  // For notifications
  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }
}
