import 'package:cloud_firestore/cloud_firestore.dart';

class PeriodEntry {
  final String id;
  final String startDate; // "yyyy-MM-dd"
  final String? endDate; // null while ongoing
  final List<String> symptoms;
  final String notes;
  final String loggedBy;

  const PeriodEntry({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.symptoms,
    required this.notes,
    required this.loggedBy,
  });

  bool get isOngoing => endDate == null;

  int? get lengthInDays {
    if (endDate == null) return null;
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate!);
    return end.difference(start).inDays + 1;
  }

  factory PeriodEntry.fromMap(String id, Map<String, dynamic> map) {
    return PeriodEntry(
      id: id,
      startDate: map['startDate'] as String,
      endDate: map['endDate'] as String?,
      symptoms: List<String>.from(map['symptoms'] ?? const []),
      notes: map['notes'] as String? ?? '',
      loggedBy: map['loggedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate,
      'endDate': endDate,
      'symptoms': symptoms,
      'notes': notes,
      'loggedBy': loggedBy,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }
}
