import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_note.dart';
import '../../services/calendar_service.dart';
import '../../utils/quill_text.dart';
import 'event_editor_screen.dart';
import '../../widgets/search_bar.dart';

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
      // floatingActionButton: SizedBox(
      //   width: 64,
      //   height: 64,
      //   child: FloatingActionButton(
      //     onPressed: () => Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (_) => EventEditorScreen(
      //           coupleId: widget.coupleId,
      //           initialDate: now,
      //         ),
      //       ),
      //     ),
      //     child: const Icon(Icons.add, size: 30),
      //   ),
      // ),
    );
  }
}

class _DateListTab extends StatefulWidget {
  final String coupleId;
  final DateTime now;
  final bool importantOnly;

  const _DateListTab({
    required this.coupleId,
    required this.now,
    required this.importantOnly,
  });

  @override
  State<_DateListTab> createState() => _DateListTabState();
}

class _DateListTabState extends State<_DateListTab> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendarService = CalendarService();

    return StreamBuilder<List<CalendarNote>>(
      stream: calendarService.watchAllNotes(widget.coupleId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final query = _search.toLowerCase().trim();

        var notes = widget.importantOnly
            ? snapshot.data!.where((n) => n.isImportant).toList()
            : snapshot.data!;

        if (query.isNotEmpty) {
          notes = notes.where((note) {
            return note.title.toLowerCase().contains(query) ||
                extractPlainText(
                  note.contentJson,
                ).toLowerCase().contains(query);
          }).toList();
        }

        if (notes.isEmpty) {
          return Column(
            children: [
              _buildSearchBar(context),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _search.isEmpty
                          ? (widget.importantOnly
                                ? 'No important dates marked yet.\nMark a note as important from the Calendar tab.'
                                : 'No events yet.\nCreate one from the Calendar tab.')
                          : 'No matching events found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final withOccurrence = notes
            .map((n) => (note: n, next: n.nextOccurrence(widget.now)))
            .toList();

        final upcoming =
            withOccurrence
                .where(
                  (e) => !e.next.isBefore(
                    DateTime(widget.now.year, widget.now.month, widget.now.day),
                  ),
                )
                .toList()
              ..sort((a, b) => a.next.compareTo(b.next));

        final past =
            withOccurrence
                .where(
                  (e) => e.next.isBefore(
                    DateTime(widget.now.year, widget.now.month, widget.now.day),
                  ),
                )
                .toList()
              ..sort((a, b) => b.next.compareTo(a.next));

        return Column(
          children: [
            _buildSearchBar(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  if (upcoming.isNotEmpty) ...[
                    const Text(
                      'Upcoming',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...upcoming.map(
                      (e) => _DateTile(
                        coupleId: widget.coupleId,
                        note: e.note,
                        occurrence: e.next,
                        now: widget.now,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (past.isNotEmpty) ...[
                    Text(
                      'Past',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...past.map(
                      (e) => _DateTile(
                        coupleId: widget.coupleId,
                        note: e.note,
                        occurrence: e.next,
                        now: widget.now,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: OkaeriSearchBar(
        controller: _searchController,
        hintText: 'Search events...',
        onChanged: (value) {
          setState(() {
            _search = value;
          });
        },
      ),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
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
          leading: note.isImportant
              ? Icon(
                  Icons.favorite,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          title: Text(
            note.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('MMMM d, yyyy').format(occurrence)}'
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
