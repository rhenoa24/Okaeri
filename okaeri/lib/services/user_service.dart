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

  // Gets a user's FCM token
  Future<String?> getFcmToken(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) return null;

    return doc.data()?['fcmToken'] as String?;
  }

  // Wipe the FCM token before signing out
  Future<void> clearFcmToken(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': FieldValue.delete(),
    });
  }

  // For Base64 photos
  Stream<String?> watchPhotoBase64(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['photoBase64'] as String?);
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoBase64,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (photoBase64 != null) data['photoBase64'] = photoBase64;
    if (data.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update(data);
  }
}
