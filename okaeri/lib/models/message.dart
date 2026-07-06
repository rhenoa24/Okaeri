import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime updatedAt;

  Message({
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.updatedAt,
  });

  // Convert Firestore document -> Message object
  // fromMap — reads raw Firestore data and turns it into a typed Dart object your UI can safely use
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      authorUid: map['authorUid'] ?? '',
      authorName: map['authorName'] ?? '',
      text: map['text'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert Message object -> Firestore document
  // toMap — does the reverse when you write a new message
  Map<String, dynamic> toMap() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text,
      'updatedAt': Timestamp.fromDate(
        updatedAt,
      ), //Using Timestamp (Firestore's native date type) instead of raw strings keeps sorting/formatting reliable later
    };
  }
}
