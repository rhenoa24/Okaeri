import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

// The service only knows about Message objects — it never touches raw maps outside of translating to/from Firestore.
// Your UI will only ever work with Message, watchMessage(), and setMessage().
class MessageService {
  final CollectionReference _messageBoard = FirebaseFirestore.instance
      .collection('messageBoard');

  // Real-time stream of a single partner's message
  // watchMessage() returns a Stream — this is Flutter's real-time listener. Whenever the Firestore doc changes (your boyfriend writes a new message),
  // this stream automatically emits the new value and your UI updates. No refresh button needed.
  Stream<Message?> watchMessage(String partnerId) {
    return _messageBoard.doc(partnerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Message.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  // Write/overwrite a partner's message
  // setMessage() uses .set() (not .add()) — this overwrites the doc at that exact ID every time,
  // which matches your README's "writing a new one replaces the previous one" behavior.
  Future<void> setMessage({
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

    await _messageBoard.doc(partnerId).set(message.toMap());
  }
}
