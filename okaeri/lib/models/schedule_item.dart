class ScheduleItem {
  final String id;
  final String date; // 'YYYY-MM-DD'
  final String time; // 'HH:mm', 24-hour, sortable as a string
  final String text;
  final String createdBy;

  ScheduleItem({
    required this.id,
    required this.date,
    required this.time,
    required this.text,
    required this.createdBy,
  });

  factory ScheduleItem.fromMap(String id, Map<String, dynamic> map) {
    return ScheduleItem(
      id: id,
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      text: map['text'] ?? '',
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'date': date, 'time': time, 'text': text, 'createdBy': createdBy};
  }
}
