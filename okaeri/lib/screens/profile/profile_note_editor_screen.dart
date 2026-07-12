import 'package:flutter/material.dart';
import '../../models/user_note.dart';

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
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isSaving = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    // TODO: persist via a NoteService, e.g.
    // await NoteService().saveNote(uid: widget.uid, note: note);
    final note = UserNote(
      id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      updatedAt: DateTime.now(),
      category: widget.category,
    );

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

    // TODO: persist via NoteService, e.g.
    // await NoteService().deleteNote(uid: widget.uid, id: widget.note!.id);
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          TextField(
            controller: _titleController,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Title',
            ),
          ),
          const Divider(height: 24),
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 8,
            style: const TextStyle(height: 1.5),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.category == NoteCategory.favorite
                  ? 'Something they love...'
                  : 'Write something about them...',
            ),
          ),
        ],
      ),
    );
  }
}
