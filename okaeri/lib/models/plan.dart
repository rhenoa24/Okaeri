import 'package:cloud_firestore/cloud_firestore.dart';

/// A single row inside a Plan's timetable, e.g.
/// "7:00 PM — Dinner at our ramen place".
class TimetableEntry {
  final String id;
  final String time; // 'HH:mm'
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

class Plan {
  final String id;
  final String date; // YYYY-MM-DD
  final String title;
  final List<TimetableEntry> timetable;
  final String createdBy;
  final DateTime createdAt;

  Plan({
    required this.id,
    required this.date,
    required this.title,
    required this.timetable,
    required this.createdBy,
    required this.createdAt,
  });

  DateTime get parsedDate {
    final parts = date.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

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
      timetable: rawTimetable
          .map((e) => TimetableEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'title': title,
      'timetable': timetable.map((e) => e.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
