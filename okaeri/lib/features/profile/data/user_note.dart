import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Which tab a note belongs to on someone's profile.
enum NoteCategory { favorite, note }

class UserNote {
  final String id;
  final String title;

  /// Quill Delta stored as JSON.
  final String contentJson;

  final DateTime updatedAt;
  final NoteCategory category;

  const UserNote({
    required this.id,
    required this.title,
    required this.contentJson,
    required this.updatedAt,
    required this.category,
  });

  /// Converts the Quill document into plain text for previews/search.
  String get plainText {
    try {
      final doc = quill.Document.fromJson(jsonDecode(contentJson));
      return doc.toPlainText().trim();
    } catch (_) {
      return '';
    }
  }

  UserNote copyWith({
    String? title,
    String? contentJson,
    DateTime? updatedAt,
    NoteCategory? category,
  }) {
    return UserNote(
      id: id,
      title: title ?? this.title,
      contentJson: contentJson ?? this.contentJson,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }

  factory UserNote.fromMap(String id, Map<String, dynamic> map) {
    return UserNote(
      id: id,
      title: map['title'] ?? '',
      contentJson: map['contentJson'] ?? '',
      updatedAt: (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      category: map['category'] == 'favorite'
          ? NoteCategory.favorite
          : NoteCategory.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'contentJson': contentJson,
      'updatedAt': updatedAt,
      'category': category == NoteCategory.favorite ? 'favorite' : 'note',
    };
  }
}
