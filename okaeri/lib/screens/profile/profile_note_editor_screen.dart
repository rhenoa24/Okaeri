import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../models/user_note.dart';
import '../../services/profile_notes_service.dart';

/// Result handed back to the profile screen so it can update its local
/// list without a full refetch. TODO: once notes are persisted, this can
/// likely go away in favor of a live stream.
class NoteEditorResult {
  final UserNote? saved;
  final String? deletedId;
  const NoteEditorResult.saved(UserNote note) : saved = note, deletedId = null;
  const NoteEditorResult.deleted(String id) : saved = null, deletedId = id;
}

class NoteEditorScreen extends StatefulWidget {
  final String uid;
  final NoteCategory category;
  final UserNote? note; // null when creating a new one

  const NoteEditorScreen({
    super.key,
    required this.uid,
    required this.category,
    this.note,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final ProfileNotesService _notesService = ProfileNotesService();

  late final TextEditingController _titleController;
  late quill.QuillController _quillController;

  bool _isSaving = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.note?.title ?? '');

    if (widget.note != null) {
      try {
        final document = quill.Document.fromJson(
          jsonDecode(widget.note!.contentJson),
        );

        _quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _quillController = quill.QuillController.basic();
      }
    } else {
      _quillController = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text.trim();

    final note = UserNote(
      id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      contentJson: jsonEncode(_quillController.document.toDelta().toJson()),
      updatedAt: DateTime.now(),
      category: widget.category,
    );

    await _notesService.saveNote(uid: widget.uid, note: note);

    if (!mounted) return;

    setState(() => _isSaving = false);

    Navigator.pop(context, NoteEditorResult.saved(note));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this?'),
        content: const Text('This can\'t be undone.'),
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
    if (confirmed != true) return;

    await _notesService.deleteNote(uid: widget.uid, noteId: widget.note!.id);
    if (!mounted) return;
    Navigator.pop(context, NoteEditorResult.deleted(widget.note!.id));
  }

  String get _label =>
      widget.category == NoteCategory.favorite ? 'favorite' : 'note';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New $_label' : 'Edit $_label'),
        actions: [
          if (!_isNew)
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
                : Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _titleController,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: 'Untitled',
                  border: InputBorder.none,
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
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
