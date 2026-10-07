import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../calendar/data/calendar_note.dart';
import '../../calendar/data/calendar_service.dart';
import '../../../core/utils/quill_text.dart';
import '../../../core/widgets/search_bar.dart';
import '../../calendar/ui/events/event_editor_screen.dart';

// Markers are compared with the variation selector (U+FE0F) stripped so
// "❣" and "❣️" both match, and the fire heart matches however the keyboard
// encoded it.
const _fireHeart = '\u2764\u200D\u{1F525}';
const _heartExclamation = '\u2763';

String _normalize(String s) => s.replaceAll('\uFE0F', '');

String _entryText(CalendarNote n) =>
    _normalize('${n.title}\n${extractPlainText(n.contentJson)}');

bool hasFireHeart(CalendarNote n) => _entryText(n).contains(_fireHeart);

bool hasHeartExclamation(CalendarNote n) =>
    _entryText(n).contains(_heartExclamation);

/// True if the note's title or body contains either marker.
/// Shared by the Home card and this screen so they always agree.
bool isRendezvousEntry(CalendarNote n) {
  final text = _entryText(n);
  return text.contains(_fireHeart) || text.contains(_heartExclamation);
}

class RendezvousStats {
  final DateTime? lastDate;
  final int fireHearts;
  final int heartExclamations;
  const RendezvousStats({
    required this.lastDate,
    required this.fireHearts,
    required this.heartExclamations,
  });
}

/// Totals and most recent date. Entries dated in the future (planned, not yet
/// happened) are ignored. An entry containing both markers counts toward both.
RendezvousStats computeRendezvousStats(List<CalendarNote> all, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime? last;
  var fire = 0;
  var exclaim = 0;

  for (final n in all) {
    final d = n.parsedDate;
    if (d.isAfter(today)) continue;
    final f = hasFireHeart(n);
    final e = hasHeartExclamation(n);
    if (!f && !e) continue;
    if (f) fire++;
    if (e) exclaim++;
    if (last == null || d.isAfter(last)) last = d;
  }

  return RendezvousStats(
    lastDate: last,
    fireHearts: fire,
    heartExclamations: exclaim,
  );
}

/// Matching entries, newest first. Uses the stored date (when it happened),
/// not the next yearly occurrence, since this is a diary.
List<CalendarNote> rendezvousEntries(List<CalendarNote> all) {
  return all.where(isRendezvousEntry).toList()
    ..sort((a, b) => b.parsedDate.compareTo(a.parsedDate));
}

class RendezvousDiaryScreen extends StatefulWidget {
  final String coupleId;
  const RendezvousDiaryScreen({super.key, required this.coupleId});

  @override
  State<RendezvousDiaryScreen> createState() => _RendezvousDiaryScreenState();
}

class _RendezvousDiaryScreenState extends State<RendezvousDiaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CalendarService _calendarService = CalendarService();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rendezvous Diary')),
      body: StreamBuilder<List<CalendarNote>>(
        stream: _calendarService.watchAllNotes(widget.coupleId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var entries = rendezvousEntries(snapshot.data!);

          final query = _search.toLowerCase().trim();
          if (query.isNotEmpty) {
            entries = entries.where((n) {
              return n.title.toLowerCase().contains(query) ||
                  extractPlainText(n.contentJson).toLowerCase().contains(query);
            }).toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: OkaeriSearchBar(
                  controller: _searchController,
                  hintText: 'Search diary...',
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _search.isEmpty
                                ? 'No entries yet.\nAdd ❤️‍🔥 or ❣️ to an event\'s title or note and it will show up here.'
                                : 'No matching entries found.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16 + MediaQuery.of(context).padding.bottom,
                        ),
                        children: entries
                            .map(
                              (n) => _DiaryTile(
                                coupleId: widget.coupleId,
                                note: n,
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiaryTile extends StatelessWidget {
  final String coupleId;
  final CalendarNote note;

  const _DiaryTile({required this.coupleId, required this.note});

  @override
  Widget build(BuildContext context) {
    final preview = extractPlainText(note.contentJson);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Reuses the existing editor as-is (edit mode).
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventEditorScreen(
                coupleId: coupleId,
                initialDate: note.parsedDate,
                existingNote: note,
              ),
            ),
          );
        },
        child: ListTile(
          titleAlignment: ListTileTitleAlignment.titleHeight,
          title: Text(
            note.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('MMMM d, yyyy').format(note.parsedDate)),
              if (preview.isNotEmpty)
                Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
          isThreeLine: preview.isNotEmpty,
        ),
      ),
    );
  }
}
