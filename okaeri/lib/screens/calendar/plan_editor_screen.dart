import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/plan.dart';
import '../../services/calendar_service.dart';

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String time) {
  final parts = time.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

// One editable row in the timetable. Wraps a TimetableEntry's id with the
// live TimeOfDay + TextEditingController the UI mutates as the user types.
class _EditableRow {
  final String id;
  TimeOfDay time;
  final TextEditingController textController;

  _EditableRow({required this.id, required this.time, required String text})
    : textController = TextEditingController(text: text);

  void dispose() => textController.dispose();
}

class PlanEditorScreen extends StatefulWidget {
  final String coupleId;
  final DateTime initialDate; // used only when creating a new plan
  final Plan? existingPlan;

  const PlanEditorScreen({
    super.key,
    required this.coupleId,
    required this.initialDate,
    this.existingPlan,
  });

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final CalendarService _calendarService = CalendarService();
  final _titleController = TextEditingController();
  late quill.QuillController _quillController;

  late DateTime _selectedDate;
  bool _isImportant = false;
  bool _isSaving = false;
  int _rowIdCounter = 0;

  final List<_EditableRow> _rows = [];

  late final String myId;

  bool get _isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    myId = FirebaseAuth.instance.currentUser!.uid;

    if (_isEditing) {
      final plan = widget.existingPlan!;
      _titleController.text = plan.title;
      _selectedDate = plan.parsedDate;
      _isImportant = plan.isImportant;
      for (final entry in plan.sortedTimetable) {
        _rows.add(
          _EditableRow(
            id: entry.id,
            time: _parseTime(entry.time),
            text: entry.text,
          ),
        );
      }
      try {
        final doc = quill.Document.fromJson(jsonDecode(plan.contentJson));
        _quillController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _quillController = quill.QuillController.basic();
      }
    } else {
      _selectedDate = widget.initialDate;
      _quillController = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2045, 12, 31),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _addRow() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      _rows.add(
        _EditableRow(id: 'row_${_rowIdCounter++}', time: picked, text: ''),
      );
    });
  }

  Future<void> _editRowTime(_EditableRow row) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: row.time,
    );
    if (picked == null) return;
    setState(() => row.time = picked);
  }

  void _removeRow(_EditableRow row) {
    setState(() => _rows.remove(row));
    row.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    final contentJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    final title = _titleController.text.trim();
    final date = _formatDate(_selectedDate);
    final timetable = _rows
        .map(
          (r) => TimetableEntry(
            id: r.id,
            time: _formatTime(r.time),
            text: r.textController.text.trim(),
          ),
        )
        .where((e) => e.text.isNotEmpty)
        .toList();

    if (_isEditing) {
      await _calendarService.updatePlan(
        coupleId: widget.coupleId,
        planId: widget.existingPlan!.id,
        date: date,
        title: title,
        contentJson: contentJson,
        timetable: timetable,
        isImportant: _isImportant,
      );
    } else {
      await _calendarService.createPlan(
        coupleId: widget.coupleId,
        date: date,
        title: title,
        contentJson: contentJson,
        timetable: timetable,
        isImportant: _isImportant,
        createdBy: myId,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _calendarService.deletePlan(
        widget.coupleId,
        widget.existingPlan!.id,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildTimetableSection() {
    final sorted = [..._rows]
      ..sort((a, b) {
        final aMin = a.time.hour * 60 + a.time.minute;
        final bMin = b.time.hour * 60 + b.time.minute;
        return aMin.compareTo(bMin);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Timetable',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add time'),
              ),
            ],
          ),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No times yet. Add one to start building the schedule.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ...sorted.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _editRowTime(row),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        row.time.format(context),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: row.textController,
                      decoration: const InputDecoration(
                        hintText: "What's happening?",
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeRow(row),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Plan' : 'New Plan'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Plan title',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_calendar_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'EEEE, MMMM d, yyyy',
                            ).format(_selectedDate),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Mark as important'),
                    subtitle: const Text('Shows up on the Home dashboard'),
                    value: _isImportant,
                    onChanged: (v) => setState(() => _isImportant = v),
                  ),
                  const Divider(height: 1),
                  _buildTimetableSection(),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 220,
                      child: quill.QuillEditor.basic(
                        controller: _quillController,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: quill.QuillSimpleToolbar(controller: _quillController),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
