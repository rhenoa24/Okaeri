import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MoodCard extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? mood;
  final bool isMe;

  const MoodCard({
    super.key,
    required this.label,
    required this.mood,
    required this.isMe,
  });

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final hasMood = mood != null;

    final emoji = hasMood ? (mood!['emoji'] ?? '🙂') : '🙂';

    final text = hasMood
        ? ((mood!['template'] as String?) ?? '{name} has no mood').replaceAll(
            '{name}',
            label,
          )
        : 'No mood yet';

    final updatedAt = hasMood
        ? (mood!['updatedAt'] as Timestamp).toDate()
        : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey('$emoji$text'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),

            const SizedBox(width: 12),

            Text(
              _relativeTime(updatedAt!),
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
