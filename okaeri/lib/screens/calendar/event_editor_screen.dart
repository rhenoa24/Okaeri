import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_note.dart';
import '../../services/calendar_service.dart';

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class EventEditorScreen extends StatefulWidget {
  final String coupleId;
  final DateTime initialDate; // used only when creating a new note
  final CalendarNote? existingNote;

  const EventEditorScreen({
    super.key,
    required this.coupleId,
    required this.initialDate,
    this.existingNote,
  });

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final CalendarService _calendarService = CalendarService();
  final _titleController = TextEditingController();
  late quill.QuillController _quillController;

  late DateTime _selectedDate;
  bool _isRepeating = false;
  bool _isImportant = false;
  bool _isSaving = false;

  late final String myId;

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    myId = FirebaseAuth.instance.currentUser!.uid;

    if (_isEditing) {
      final note = widget.existingNote!;
      _titleController.text = note.title;
      _selectedDate = note.parsedDate;
      _isRepeating = note.isRepeating;
      _isImportant = note.isImportant;
      try {
        final doc = quill.Document.fromJson(jsonDecode(note.contentJson));
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

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    final contentJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    final title = _titleController.text.trim();
    final date = _formatDate(_selectedDate);

    if (_isEditing) {
      await _calendarService.updateNote(
        coupleId: widget.coupleId,
        noteId: widget.existingNote!.id,
        date: date,
        title: title,
        contentJson: contentJson,
        isRepeating: _isRepeating,
        isImportant: _isImportant,
      );
    } else {
      await _calendarService.createNote(
        coupleId: widget.coupleId,
        date: date,
        title: title,
        contentJson: contentJson,
        isRepeating: _isRepeating,
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
        title: const Text('Delete this note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _calendarService.deleteNote(
        widget.coupleId,
        widget.existingNote!.id,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'New Event'),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Untitled',
                  border: InputBorder.none,
                ),
              ),
            ),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                initiallyExpanded: false,
                title: InkWell(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_calendar_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat(
                              'EEEE, MMMM d, yyyy',
                            ).format(_selectedDate),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                children: [
                  SwitchListTile(
                    title: const Text('Repeats every year'),
                    subtitle: const Text('Good for birthdays & anniversaries'),
                    value: _isRepeating,
                    onChanged: (v) => setState(() => _isRepeating = v),
                  ),
                  SwitchListTile(
                    title: const Text('Mark as important'),
                    subtitle: const Text('Shows up on the Home dashboard'),
                    value: _isImportant,
                    onChanged: (v) => setState(() => _isImportant = v),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: quill.QuillEditor.basic(controller: _quillController),
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
