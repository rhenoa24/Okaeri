import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_note.dart';
import '../../services/calendar_service.dart';
import '../../utils/quill_text.dart';

String _daysUntilLabel(DateTime target, DateTime from) {
  final t = DateTime(target.year, target.month, target.day);
  final f = DateTime(from.year, from.month, from.day);
  final diff = t.difference(f).inDays;
  if (diff == 0) return 'Today 🎉';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1) return 'In $diff days';
  if (diff == -1) return 'Yesterday';
  return '${-diff} days ago';
}

class ImportantDatesScreen extends StatelessWidget {
  final String coupleId;
  const ImportantDatesScreen({super.key, required this.coupleId});

  @override
  Widget build(BuildContext context) {
    final calendarService = CalendarService();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Important Dates')),
      body: StreamBuilder<List<CalendarNote>>(
        stream: calendarService.watchAllNotes(coupleId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final important = snapshot.data!.where((n) => n.isImportant).toList();

          if (important.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No important dates marked yet.\nMark a note as important from the Calendar tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final withOccurrence = important
              .map((n) => (note: n, next: n.nextOccurrence(now)))
              .toList();

          final upcoming =
              withOccurrence
                  .where(
                    (e) => !e.next.isBefore(
                      DateTime(now.year, now.month, now.day),
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.next.compareTo(b.next));

          final past =
              withOccurrence
                  .where(
                    (e) =>
                        e.next.isBefore(DateTime(now.year, now.month, now.day)),
                  )
                  .toList()
                ..sort((a, b) => b.next.compareTo(a.next));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                const Text(
                  'Upcoming',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...upcoming.map(
                  (e) => _DateTile(note: e.note, occurrence: e.next, now: now),
                ),
                const SizedBox(height: 24),
              ],
              if (past.isNotEmpty) ...[
                const Text(
                  'Past',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...past.map(
                  (e) => _DateTile(note: e.note, occurrence: e.next, now: now),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final CalendarNote note;
  final DateTime occurrence;
  final DateTime now;

  const _DateTile({
    required this.note,
    required this.occurrence,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final preview = extractPlainText(note.contentJson);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.star, color: Colors.amber.shade700),
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${DateFormat('MMMM d').format(occurrence)}'
          '${note.isRepeating ? ' (yearly)' : ''}'
          '${preview.isNotEmpty ? '\n$preview' : ''}',
        ),
        isThreeLine: preview.isNotEmpty,
        trailing: Text(
          _daysUntilLabel(occurrence, now),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
