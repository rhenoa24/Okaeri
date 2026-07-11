import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/moodlet.dart';
import 'notification_sender.dart';

class MoodletService {
  final _firestore = FirebaseFirestore.instance;

  /// Sets the current user's active moodlet and notifies their partner.
  /// [partnerId] and [partnerToken] can be null (e.g. not paired yet, or
  /// partner hasn't registered a device token) — the moodlet still saves,
  /// the notification is just skipped in that case.
  Future<void> sendMoodlet({
    required String uid,
    required String senderName,
    required Moodlet moodlet,
    String? partnerId,
    String? partnerToken,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'currentMoodlet': {
        'id': moodlet.id,
        'label': moodlet.label,
        'template': moodlet.template,
        'emoji': moodlet.emoji,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
    }, SetOptions(merge: true));
    if (partnerToken != null) {
      NotificationSender.send(
        token: partnerToken,
        title: moodlet.template.replaceAll('{name}', senderName),
        body: '',
      );
    }
  }

  /// Watches a user's current moodlet (null if none set yet).
  Stream<Map<String, dynamic>?> watchMoodlet(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      return doc.data()?['currentMoodlet'] as Map<String, dynamic>?;
    });
  }
}
