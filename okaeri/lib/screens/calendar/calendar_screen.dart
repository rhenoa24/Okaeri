import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_note.dart';
import '../../models/plan.dart';
import '../../services/calendar_service.dart';
import '../../utils/quill_text.dart';
import 'events_screen.dart';
import 'plans_screen.dart';
import 'plan_editor_screen.dart';
import 'event_editor_screen.dart';

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum CalendarMarkerType { importantDate, normalNote, schedule }

class CalendarMarker {
  const CalendarMarker(this.type);
  final CalendarMarkerType type;
}

List<CalendarMarker> buildCalendarDayMarkers({
  required DateTime day,
  required List<CalendarNote> notes,
  required List<Plan> plans,
}) {
  final dayStr = _formatDate(day);
  final monthDay = dayStr.substring(5);

  final noteMarkers = notes
      .where(
        (note) =>
            note.date == dayStr ||
            (note.isRepeating && note.monthDay == monthDay),
      )
      .map(
        (note) => CalendarMarker(
          note.isImportant
              ? CalendarMarkerType.importantDate
              : CalendarMarkerType.normalNote,
        ),
      )
      .toList();

  final planMarkers = plans
      .where((plan) => plan.date == dayStr)
      .map((_) => CalendarMarker(CalendarMarkerType.schedule))
      .toList();

  return [...noteMarkers, ...planMarkers];
}

class CalendarScreen extends StatefulWidget {
  final String coupleId;
  const CalendarScreen({super.key, required this.coupleId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();
  late final String myId;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    myId = FirebaseAuth.instance.currentUser!.uid;
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = now;
      _selectedDay = now;
    });
  }

  List<CalendarNote> _notesForDay(DateTime day, List<CalendarNote> allNotes) {
    final dayStr = _formatDate(day);
    final monthDay = dayStr.substring(5);
    return allNotes
        .where(
          (n) => n.date == dayStr || (n.isRepeating && n.monthDay == monthDay),
        )
        .toList();
  }

  List<Plan> _plansForDay(DateTime day, List<Plan> allPlans) {
    final dayStr = _formatDate(day);
    return allPlans.where((item) => item.date == dayStr).toList();
  }

  void _openNoteEditor({CalendarNote? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventEditorScreen(
          coupleId: widget.coupleId,
          initialDate: _selectedDay,
          existingNote: existing,
        ),
      ),
    );
  }

  // A plan now carries a title, notes, and a whole timetable, so it needs
  // the full editor screen rather than the old single-time bottom sheet.
  void _openPlanEditor({Plan? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanEditorScreen(
          coupleId: widget.coupleId,
          initialDate: _selectedDay,
          existingPlan: existing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: 'Important Dates',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventsScreen(coupleId: widget.coupleId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.alarm),
            tooltip: 'Upcoming Plans',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlansScreen(coupleId: widget.coupleId),
                ),
              );
            },
          ),
          if (!(_focusedDay.year == DateTime.now().year &&
              _focusedDay.month == DateTime.now().month))
            IconButton(
              icon: const Icon(Icons.today_outlined),
              tooltip: 'Jump to Today',
              onPressed: _jumpToToday,
            ),
        ],
      ),
      body: StreamBuilder<CalendarData>(
        stream: _calendarService.watchCalendarData(widget.coupleId),
        builder: (context, calendarSnapshot) {
          if (!calendarSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final calendarData = calendarSnapshot.data!;
          final allNotes = calendarData.notes;
          final allPlans = calendarData.plans;
          final selectedNotes = _notesForDay(_selectedDay, allNotes);
          final selectedPlans = _plansForDay(_selectedDay, allPlans);

          return Column(
            children: [
              TableCalendar<CalendarMarker>(
                firstDay: DateTime.utc(2015, 1, 1),
                lastDay: DateTime.utc(2045, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
                eventLoader: (day) => buildCalendarDayMarkers(
                  day: day,
                  notes: allNotes,
                  plans: allPlans,
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, markers) {
                    if (markers.isEmpty) return null;
                    final markerItems = markers.cast<CalendarMarker>();
                    return Positioned(
                      bottom: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: markerItems.map((marker) {
                          final symbol = switch (marker.type) {
                            CalendarMarkerType.importantDate => '❤️',
                            CalendarMarkerType.normalNote => '🔵',
                            CalendarMarkerType.schedule => '🕒',
                          };
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Text(
                              symbol,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                calendarStyle: CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SectionHeader(
                      title: 'Events',
                      onAdd: () => _openNoteEditor(),
                    ),
                    const SizedBox(height: 8),
                    if (selectedNotes.isEmpty)
                      const _EmptyHint(text: 'No events for this day yet.')
                    else
                      ...selectedNotes.map(
                        (n) => _NoteTile(
                          note: n,
                          onTap: () => _openNoteEditor(existing: n),
                        ),
                      ),

                    const SizedBox(height: 28),

                    _SectionHeader(
                      title: 'Plans',
                      onAdd: () => _openPlanEditor(),
                    ),
                    const SizedBox(height: 8),
                    if (selectedPlans.isEmpty)
                      const _EmptyHint(text: 'No plans for this day yet.')
                    else
                      Column(
                        children: selectedPlans
                            .map(
                              (item) => _ScheduleRow(
                                item: item,
                                onTap: () => _openPlanEditor(existing: item),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;

  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onAdd,
          visualDensity: VisualDensity.compact,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final CalendarNote note;
  final VoidCallback onTap;

  const _NoteTile({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = extractPlainText(note.contentJson);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        titleAlignment: ListTileTitleAlignment.titleHeight,
        leading: note.isImportant
            ? Icon(
                Icons.favorite_rounded,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: preview.isEmpty
            ? null
            : Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: note.isRepeating
            ? Icon(
                Icons.repeat,
                size: 18,
                color: Theme.of(context).colorScheme.outline,
              )
            : null,
      ),
    );
  }
}

// One plan in the day view: title up top, then a compact preview of its
// timetable rows underneath (a plan can have several times now, not just
// one), same idea as the cards on the full Plans screen.
class _ScheduleRow extends StatelessWidget {
  final Plan item;
  final VoidCallback onTap;

  const _ScheduleRow({required this.item, required this.onTap});

  String _displayTime(String time) {
    final hour = int.parse(time.split(':')[0]);
    final minute = time.split(':')[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final entries = item.sortedTimetable;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // timetable widgets
            if (entries.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'No timetable yet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          _displayTime(e.time),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.text,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
