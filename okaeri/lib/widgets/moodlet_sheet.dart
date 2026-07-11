import 'package:flutter/material.dart';
import '../models/moodlet.dart';

/// Shows the moodlet picker as a bottom sheet. Returns the selected
/// [Moodlet], or null if the user dismissed it without picking one.
Future<Moodlet?> showMoodletSheet(BuildContext context) {
  return showModalBottomSheet<Moodlet>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _MoodletSheetContent(),
  );
}

class _MoodletSheetContent extends StatelessWidget {
  const _MoodletSheetContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a moodlet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Let your partner know how you\'re feeling',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Moodlet.premade.map((moodlet) {
                return _MoodletChip(
                  moodlet: moodlet,
                  onTap: () => Navigator.of(context).pop(moodlet),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            _CustomMoodField(),
          ],
        ),
      ),
    );
  }
}

class _MoodletChip extends StatelessWidget {
  final Moodlet moodlet;
  final VoidCallback onTap;

  const _MoodletChip({required this.moodlet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(moodlet.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(moodlet.label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _CustomMoodField extends StatefulWidget {
  const _CustomMoodField();

  @override
  State<_CustomMoodField> createState() => _CustomMoodFieldState();
}

class _CustomMoodFieldState extends State<_CustomMoodField> {
  final _controller = TextEditingController();

  void _send() {
    var text = _controller.text.trim();

    if (text.isEmpty) return;

    if (!text.contains('{name}')) {
      text = '{name} $text';
    }

    Navigator.of(
      context,
    ).pop(Moodlet(id: 'custom', label: 'Custom', emoji: '💭', template: text));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Write your own mood...',
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _send,
          icon: const Icon(Icons.send, size: 18),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(padding: const EdgeInsets.all(20)),
        ),
      ],
    );
  }
}
