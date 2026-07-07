import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  final String title;
  final String contentJson; // Quill Delta encoded as a JSON string
  final String visibility; // 'shared' or 'private:<uid>'
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.contentJson,
    required this.visibility,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isShared => visibility == 'shared';

  factory Note.fromMap(String id, Map<String, dynamic> map) {
    return Note(
      id: id,
      title: map['title'] ?? '',
      contentJson: map['contentJson'] ?? '',
      visibility: map['visibility'] ?? 'shared',
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'contentJson': contentJson,
      'visibility': visibility,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
