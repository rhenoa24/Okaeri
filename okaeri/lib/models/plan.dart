import 'package:cloud_firestore/cloud_firestore.dart';

/// A single row inside a Plan's timetable, e.g. "7:00 PM — Dinner at our
/// ramen place". Lives only inside a Plan document, never on its own.
class TimetableEntry {
  final String id;
  final String time; // 'HH:mm', 24-hour, sortable as a string
  final String text;

  TimetableEntry({required this.id, required this.time, required this.text});

  factory TimetableEntry.fromMap(Map<String, dynamic> map) {
    return TimetableEntry(
      id: map['id'] ?? '',
      time: map['time'] ?? '',
      text: map['text'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'time': time, 'text': text};

  TimetableEntry copyWith({String? time, String? text}) {
    return TimetableEntry(
      id: id,
      time: time ?? this.time,
      text: text ?? this.text,
    );
  }
}

/// A plan is one titled event that owns a whole timetable, e.g.
/// "Anniversary Day" with rows for dinner, then the movie, then dessert.
/// This replaces the old model where each timestamp was its own document.
class Plan {
  final String id;
  final String date; // 'YYYY-MM-DD'
  final String title;
  final String contentJson; // quill delta — optional notes/description
  final List<TimetableEntry> timetable;
  final bool isImportant;
  final String createdBy;
  final DateTime createdAt;

  Plan({
    required this.id,
    required this.date,
    required this.title,
    required this.contentJson,
    required this.timetable,
    required this.isImportant,
    required this.createdBy,
    required this.createdAt,
  });

  DateTime get parsedDate {
    final parts = date.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  // Timetable rows, earliest first. Sorting happens here (client-side)
  // rather than in Firestore since it's just a small embedded array.
  List<TimetableEntry> get sortedTimetable {
    final copy = [...timetable];
    copy.sort((a, b) => a.time.compareTo(b.time));
    return copy;
  }

  factory Plan.fromMap(String id, Map<String, dynamic> map) {
    final rawTimetable = (map['timetable'] as List<dynamic>? ?? []);
    return Plan(
      id: id,
      date: map['date'] ?? '',
      title: map['title'] ?? '',
      contentJson: map['contentJson'] ?? '',
      timetable: rawTimetable
          .map((e) => TimetableEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      isImportant: map['isImportant'] ?? false,
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'title': title,
      'contentJson': contentJson,
      'timetable': timetable.map((e) => e.toMap()).toList(),
      'isImportant': isImportant,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
