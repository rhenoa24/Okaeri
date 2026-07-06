import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoupleService {
  final _firestore = FirebaseFirestore.instance;

  // Watch this user's coupleId (null until paired)
  Stream<String?> watchCoupleId(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      return doc.data()?['coupleId'] as String?;
    });
  }

  // Watch the couple doc itself (to check member count, get invite code)
  Stream<Map<String, dynamic>?> watchCouple(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .snapshots()
        .map((doc) => doc.data());
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I confusion
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // Person A: create a new couple + invite code
  Future<String> createInvite(String uid) async {
    final coupleRef = _firestore.collection('couples').doc();
    final code = _generateCode();

    await coupleRef.set({
      'members': [uid],
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('invites').doc(code).set({
      'creatorUid': uid,
      'coupleId': coupleRef.id,
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(uid).set({
      'coupleId': coupleRef.id,
    }, SetOptions(merge: true));

    return code;
  }

  // Person B: join using a code
  Future<String?> joinWithCode(String uid, String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    final inviteRef = _firestore.collection('invites').doc(code);
    final inviteSnap = await inviteRef.get();

    if (!inviteSnap.exists) return 'Invalid invite code';
    final data = inviteSnap.data()!;

    if (data['used'] == true) return 'This code has already been used';
    if (data['creatorUid'] == uid) return "You can't join your own invite";

    final coupleId = data['coupleId'] as String;

    await _firestore.collection('couples').doc(coupleId).update({
      'members': FieldValue.arrayUnion([uid]),
    });

    await _firestore.collection('users').doc(uid).set({
      'coupleId': coupleId,
    }, SetOptions(merge: true));

    await inviteRef.update({'used': true});

    return null; // success
  }
}
