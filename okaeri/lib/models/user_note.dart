/// Which tab a note belongs to on someone's profile.
enum NoteCategory { favorite, note }

/// A single note attached to a profile — used by both the "Favorites" tab
/// (things they love) and the "Notes" tab (things you've written about
/// them). Distinct from the "My Corner" private journal notes elsewhere
/// in the app.
class UserNote {
  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;
  final NoteCategory category;

  const UserNote({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.category,
  });

  UserNote copyWith({String? title, String? content, DateTime? updatedAt}) {
    return UserNote(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category,
    );
  }

  // TODO: wire to Firestore, e.g. a subcollection at
  // users/{uid}/profileNotes/{noteId} with a `category` field.
  factory UserNote.fromMap(String id, Map<String, dynamic> map) {
    return UserNote(
      id: id,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      category: (map['category'] as String?) == 'favorite'
          ? NoteCategory.favorite
          : NoteCategory.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'updatedAt': updatedAt.toIso8601String(),
      'category': category == NoteCategory.favorite ? 'favorite' : 'note',
    };
  }
}
