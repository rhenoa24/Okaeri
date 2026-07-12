import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../models/user_note.dart';

/// A searchable list of full (untruncated) note previews. Used for both
/// the "Favorites" and "Notes" tabs — [category] just controls copy and
/// what a newly-created note gets tagged as.
class NoteCollectionTab extends StatefulWidget {
  final NoteCategory category;
  final String emptyLabel;
  final List<UserNote> notes;
  final ValueChanged<UserNote> onTapNote;

  const NoteCollectionTab({
    super.key,
    required this.category,
    required this.emptyLabel,
    required this.notes,
    required this.onTapNote,
  });

  @override
  State<NoteCollectionTab> createState() => _NoteCollectionTabState();
}

class _NoteCollectionTabState extends State<NoteCollectionTab>
    with AutomaticKeepAliveClientMixin {
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

    final filtered = widget.notes.where((n) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
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
                  itemBuilder: (context, i) {
                    final note = filtered[i];
                    return _NoteCard(
                      note: note,
                      onTap: () => widget.onTapNote(note),
                    );
                  },
                ),
        ),
      ],
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
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              if (note.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                // Intentionally not truncated — the profile screen is
                // meant to be read in full, unlike home-screen previews.
                Text(
                  note.content,
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
