import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_note.dart';
import '../../services/calendar_service.dart';
import '../../utils/quill_text.dart';
import 'calendar_note_editor_screen.dart';

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

class EventsScreen extends StatefulWidget {
  final String coupleId;
  const EventsScreen({super.key, required this.coupleId});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Important Dates'),
            Tab(text: 'All Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DateListTab(
            coupleId: widget.coupleId,
            now: now,
            importantOnly: true,
          ),
          _DateListTab(
            coupleId: widget.coupleId,
            now: now,
            importantOnly: false,
          ),
        ],
      ),
    );
  }
}

class _DateListTab extends StatelessWidget {
  final String coupleId;
  final DateTime now;
  final bool importantOnly;

  const _DateListTab({
    required this.coupleId,
    required this.now,
    required this.importantOnly,
  });

  @override
  Widget build(BuildContext context) {
    final calendarService = CalendarService();

    return StreamBuilder<List<CalendarNote>>(
      stream: calendarService.watchAllNotes(coupleId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notes = snapshot.data!;
        final filtered = importantOnly
            ? notes.where((n) => n.isImportant).toList()
            : notes;

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                importantOnly
                    ? 'No important dates marked yet.\nMark a note as important from the Calendar tab.'
                    : 'No events yet.\nCreate one from the Calendar tab.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final withOccurrence = filtered
            .map((n) => (note: n, next: n.nextOccurrence(now)))
            .toList();

        final upcoming =
            withOccurrence
                .where(
                  (e) =>
                      !e.next.isBefore(DateTime(now.year, now.month, now.day)),
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
                (e) => _DateTile(
                  coupleId: coupleId,
                  note: e.note,
                  occurrence: e.next,
                  now: now,
                ),
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
                (e) => _DateTile(
                  coupleId: coupleId,
                  note: e.note,
                  occurrence: e.next,
                  now: now,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DateTile extends StatelessWidget {
  final String coupleId;
  final CalendarNote note;
  final DateTime occurrence;
  final DateTime now;

  const _DateTile({
    required this.coupleId,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CalendarNoteEditorScreen(
                coupleId: coupleId,
                initialDate: note.parsedDate,
                existingNote: note,
              ),
            ),
          );
        },
        child: ListTile(
          titleAlignment: ListTileTitleAlignment.titleHeight,
          leading: note.isImportant
              ? Icon(Icons.favorite, color: Colors.red.shade400)
              : null,
          title: Text(
            note.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('MMMM d').format(occurrence)}'
                '${note.isRepeating ? ' (yearly)' : ''}',
              ),
              if (preview.isNotEmpty)
                Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
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
      ),
    );
  }
}
