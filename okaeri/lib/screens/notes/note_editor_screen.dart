import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/note.dart';
import '../../services/notes_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final String coupleId;
  final Note? existingNote;
  final String initialVisibility; // used only when creating a new note

  const NoteEditorScreen({
    super.key,
    required this.coupleId,
    this.existingNote,
    this.initialVisibility = 'shared',
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final NotesService _notesService = NotesService();
  final _titleController = TextEditingController();
  late quill.QuillController _quillController;

  late bool _isShared;
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
      _isShared = note.isShared;
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
      _isShared = widget.initialVisibility == 'shared';
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

    final contentJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    final visibility = _isShared ? 'shared' : 'private:$myId';
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled'
        : _titleController.text.trim();

    if (_isEditing) {
      await _notesService.updateNote(
        coupleId: widget.coupleId,
        noteId: widget.existingNote!.id,
        title: title,
        contentJson: contentJson,
        visibility: visibility,
      );
    } else {
      await _notesService.createNote(
        coupleId: widget.coupleId,
        title: title,
        contentJson: contentJson,
        visibility: visibility,
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _notesService.deleteNote(widget.coupleId, widget.existingNote!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Note' : 'New Note'),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: "Untitled",
                  border: InputBorder.none,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _isShared ? Icons.home_outlined : Icons.lock_outline,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isShared ? 'Shared with your partner' : 'Private note',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isShared,
                    onChanged: (v) => setState(() => _isShared = v),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

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
