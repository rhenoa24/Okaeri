import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class MessageService {
  CollectionReference _boardRef(String coupleId) => FirebaseFirestore.instance
      .collection('couples')
      .doc(coupleId)
      .collection('messageBoard');

  Stream<Message?> watchMessage(String coupleId, String partnerId) {
    return _boardRef(coupleId).doc(partnerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Message.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Future<void> setMessage({
    required String coupleId,
    required String partnerId,
    required String authorName,
    required String text,
  }) async {
    final message = Message(
      authorUid: partnerId,
      authorName: authorName,
      text: text,
      updatedAt: DateTime.now(),
    );
    await _boardRef(coupleId).doc(partnerId).set(message.toMap());
  }
}
