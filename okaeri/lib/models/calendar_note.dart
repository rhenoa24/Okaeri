import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarNote {
  final String id;
  final String date; // 'YYYY-MM-DD'
  final String title;
  final String note;
  final bool isRepeating; // yearly repeat (birthdays, anniversaries)
  final bool isImportant;
  final String createdBy;
  final DateTime createdAt;

  CalendarNote({
    required this.id,
    required this.date,
    required this.title,
    required this.note,
    required this.isRepeating,
    required this.isImportant,
    required this.createdBy,
    required this.createdAt,
  });

  // 'MM-DD' portion, used to match repeating events across different years
  String get monthDay => date.length >= 10 ? date.substring(5) : '';

  factory CalendarNote.fromMap(String id, Map<String, dynamic> map) {
    return CalendarNote(
      id: id,
      date: map['date'] ?? '',
      title: map['title'] ?? '',
      note: map['note'] ?? '',
      isRepeating: map['isRepeating'] ?? false,
      isImportant: map['isImportant'] ?? false,
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'title': title,
      'note': note,
      'isRepeating': isRepeating,
      'isImportant': isImportant,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
