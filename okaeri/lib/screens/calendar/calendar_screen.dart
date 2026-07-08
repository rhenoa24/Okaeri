import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_note.dart';
import '../../models/schedule_item.dart';
import '../../services/calendar_service.dart';
import '../../utils/quill_text.dart';
import 'events_screen.dart';
import 'plans_screen.dart';
import 'calendar_note_editor_screen.dart';

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
  required List<ScheduleItem> plans,
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

  List<ScheduleItem> _plansForDay(DateTime day, List<ScheduleItem> allPlans) {
    final dayStr = _formatDate(day);
    return allPlans.where((item) => item.date == dayStr).toList();
  }

  void _openNoteEditor({CalendarNote? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarNoteEditorScreen(
          coupleId: widget.coupleId,
          initialDate: _selectedDay,
          existingNote: existing,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
              const Divider(height: 1),
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
                      onAdd: () => _showAddScheduleSheet(),
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
                                onTap: () =>
                                    _showAddScheduleSheet(existing: item),
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

  // ---------- Add / Edit Schedule sheet (unchanged — still a quick bottom sheet) ----------

  void _showAddScheduleSheet({ScheduleItem? existing}) {
    final textController = TextEditingController(text: existing?.text ?? '');
    TimeOfDay selectedTime = existing != null
        ? TimeOfDay(
            hour: int.parse(existing.time.split(':')[0]),
            minute: int.parse(existing.time.split(':')[1]),
          )
        : TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    existing == null
                        ? 'New Schedule Item'
                        : 'Edit Schedule Item',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setSheetState(() => selectedTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            selectedTime.format(context),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'What\'s happening?',
                      hintText: 'e.g. Dinner at our ramen place',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (existing != null)
                        TextButton(
                          onPressed: () async {
                            await _calendarService.deleteScheduleItem(
                              widget.coupleId,
                              existing.id,
                            );
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          if (textController.text.trim().isEmpty) return;
                          final timeStr =
                              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

                          if (existing == null) {
                            await _calendarService.createScheduleItem(
                              coupleId: widget.coupleId,
                              date: _formatDate(_selectedDay),
                              time: timeStr,
                              text: textController.text.trim(),
                              createdBy: myId,
                            );
                          } else {
                            await _calendarService.updateScheduleItem(
                              coupleId: widget.coupleId,
                              itemId: existing.id,
                              time: timeStr,
                              text: textController.text.trim(),
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onAdd,
          visualDensity: VisualDensity.compact,
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
        style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        titleAlignment: ListTileTitleAlignment.titleHeight,
        leading: note.isImportant
            ? Icon(Icons.favorite_rounded, color: Colors.red.shade400)
            : null,
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: preview.isEmpty
            ? null
            : Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: note.isRepeating
            ? const Icon(Icons.repeat, size: 18, color: Colors.grey)
            : null,
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback onTap;

  const _ScheduleRow({required this.item, required this.onTap});

  String get _displayTime {
    final hour = int.parse(item.time.split(':')[0]);
    final minute = item.time.split(':')[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                _displayTime,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(child: Text(item.text)),
          ],
        ),
      ),
    );
  }
}
