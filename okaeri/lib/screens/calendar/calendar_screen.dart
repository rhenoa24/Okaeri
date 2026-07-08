import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_note.dart';
import '../../models/schedule_item.dart';
import '../../services/calendar_service.dart';

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  List<CalendarNote> _notesForDay(DateTime day, List<CalendarNote> allNotes) {
    final dayStr = _formatDate(day);
    final monthDay = dayStr.substring(5);
    return allNotes
        .where(
          (n) => n.date == dayStr || (n.isRepeating && n.monthDay == monthDay),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: StreamBuilder<List<CalendarNote>>(
        stream: _calendarService.watchAllNotes(widget.coupleId),
        builder: (context, notesSnapshot) {
          final allNotes = notesSnapshot.data ?? [];
          final selectedNotes = _notesForDay(_selectedDay, allNotes);

          return Column(
            children: [
              TableCalendar<CalendarNote>(
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
                eventLoader: (day) => _notesForDay(day, allNotes),
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
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SectionHeader(
                      title: 'Notes & Important Dates',
                      onAdd: () => _showAddNoteSheet(),
                    ),
                    const SizedBox(height: 8),
                    if (selectedNotes.isEmpty)
                      const _EmptyHint(text: 'No notes for this day yet.')
                    else
                      ...selectedNotes.map(
                        (n) => _NoteTile(
                          note: n,
                          onTap: () => _showAddNoteSheet(existing: n),
                        ),
                      ),

                    const SizedBox(height: 28),

                    _SectionHeader(
                      title: 'Schedule',
                      onAdd: () => _showAddScheduleSheet(),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<ScheduleItem>>(
                      stream: _calendarService.watchScheduleForDate(
                        widget.coupleId,
                        _formatDate(_selectedDay),
                      ),
                      builder: (context, scheduleSnapshot) {
                        final items = scheduleSnapshot.data ?? [];
                        if (!scheduleSnapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (items.isEmpty) {
                          return const _EmptyHint(
                            text: 'No schedule for this day yet.',
                          );
                        }
                        return Column(
                          children: items
                              .map(
                                (item) => _ScheduleRow(
                                  item: item,
                                  onTap: () =>
                                      _showAddScheduleSheet(existing: item),
                                ),
                              )
                              .toList(),
                        );
                      },
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

  // ---------- Add / Edit Note sheet ----------

  void _showAddNoteSheet({CalendarNote? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    bool isRepeating = existing?.isRepeating ?? false;
    bool isImportant = existing?.isImportant ?? false;

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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? 'New Note' : 'Edit Note',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title (e.g. Ranjo\'s Birthday)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repeats every year'),
                      subtitle: const Text(
                        'Good for birthdays & anniversaries',
                      ),
                      value: isRepeating,
                      onChanged: (v) => setSheetState(() => isRepeating = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mark as important'),
                      subtitle: const Text('Shows up on the Home dashboard'),
                      value: isImportant,
                      onChanged: (v) => setSheetState(() => isImportant = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (existing != null)
                          TextButton(
                            onPressed: () async {
                              await _calendarService.deleteNote(
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
                            if (titleController.text.trim().isEmpty) return;
                            if (existing == null) {
                              await _calendarService.createNote(
                                coupleId: widget.coupleId,
                                date: _formatDate(_selectedDay),
                                title: titleController.text.trim(),
                                note: noteController.text.trim(),
                                isRepeating: isRepeating,
                                isImportant: isImportant,
                                createdBy: myId,
                              );
                            } else {
                              await _calendarService.updateNote(
                                coupleId: widget.coupleId,
                                noteId: existing.id,
                                date: existing.date,
                                title: titleController.text.trim(),
                                note: noteController.text.trim(),
                                isRepeating: isRepeating,
                                isImportant: isImportant,
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
              ),
            );
          },
        );
      },
    );
  }

  // ---------- Add / Edit Schedule sheet ----------

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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          note.isImportant ? Icons.star : Icons.event_note_outlined,
          color: note.isImportant ? Colors.amber.shade700 : Colors.grey,
        ),
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: note.note.isEmpty ? null : Text(note.note),
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
