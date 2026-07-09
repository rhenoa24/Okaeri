import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/note.dart';
import '../../services/notes_service.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  final String coupleId;
  const NotesScreen({super.key, required this.coupleId});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with SingleTickerProviderStateMixin {
  final NotesService _notesService = NotesService();
  late final TabController _tabController;
  late final String myId;

  @override
  void initState() {
    super.initState();
    myId = FirebaseAuth.instance.currentUser!.uid;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Our Room'),
            Tab(text: 'My Corner'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NotesGrid(
            stream: _notesService.watchSharedNotes(widget.coupleId),
            coupleId: widget.coupleId,
            emptyText:
                'No shared notes yet.\nStart writing something together!',
          ),
          _NotesGrid(
            stream: _notesService.watchPrivateNotes(widget.coupleId, myId),
            coupleId: widget.coupleId,
            emptyText:
                'Nobody else can see this space.\nJot down anything here.',
          ),
        ],
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  final Stream<List<Note>> stream;
  final String coupleId;
  final String emptyText;

  const _NotesGrid({
    required this.stream,
    required this.coupleId,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Note>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snapshot.data!;
        if (notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            return _NoteCard(note: notes[index], coupleId: coupleId);
          },
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final String coupleId;

  const _NoteCard({required this.note, required this.coupleId});

  // Pulls plain text out of the Quill Delta JSON for the preview snippet
  String _previewText() {
    try {
      final ops = jsonDecode(note.contentJson) as List<dynamic>;
      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is Map && op['insert'] is String) {
          buffer.write(op['insert']);
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  NoteEditorScreen(coupleId: coupleId, existingNote: note),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  _previewText(),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${note.updatedAt.month}/${note.updatedAt.day}/${note.updatedAt.year}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
