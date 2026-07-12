import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../models/user_note.dart';
import '../../../../../services/profile_notes_service.dart';
import '../../../../../widgets/search_bar.dart';

/// A searchable list of full (untruncated) note previews. Used for both
/// the "Favorites" and "Notes" tabs — [category] just controls copy and
/// what a newly-created note gets tagged as.
class NoteCollectionTab extends StatefulWidget {
  final NoteCategory category;
  final String emptyLabel;
  final String uid;
  final ValueChanged<UserNote> onTapNote;

  const NoteCollectionTab({
    super.key,
    required this.uid,
    required this.category,
    required this.emptyLabel,
    required this.onTapNote,
  });

  @override
  State<NoteCollectionTab> createState() => _NoteCollectionTabState();
}

class _NoteCollectionTabState extends State<NoteCollectionTab>
    with AutomaticKeepAliveClientMixin {
  final ProfileNotesService _service = ProfileNotesService();
  late final Stream<List<UserNote>> _notesStream;

  @override
  void initState() {
    super.initState();

    _notesStream = _service.watchNotes(widget.uid, widget.category);
  }

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<List<UserNote>>(
      stream: _notesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = snapshot.data!.where((note) {
          if (_query.isEmpty) return true;

          final q = _query.toLowerCase();

          return note.title.toLowerCase().contains(q) ||
              note.plainText.toLowerCase().contains(q);
        }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: OkaeriSearchBar(
                controller: _searchController,
                hintText: 'Search',
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? _EmptyNotes(
                      hasQuery: _query.isNotEmpty,
                      emptyLabel: widget.emptyLabel,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final note = filtered[index];

                        return _NoteCard(
                          note: note,
                          onTap: () => widget.onTapNote(note),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final UserNote note;
  final VoidCallback onTap;
  const _NoteCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d').format(note.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              if (note.plainText.isNotEmpty) ...[
                const SizedBox(height: 8),
                // Intentionally not truncated — the profile screen is
                // meant to be read in full, unlike home-screen previews.
                Text(
                  note.plainText,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  final bool hasQuery;
  final String emptyLabel;
  const _EmptyNotes({required this.hasQuery, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.sticky_note_2_outlined,
              size: 40,
              color: outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasQuery ? 'No matches' : emptyLabel,
              textAlign: TextAlign.center,
              style: TextStyle(color: outline),
            ),
          ],
        ),
      ),
    );
  }
}
