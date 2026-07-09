import 'package:flutter/material.dart';
import '../models/message.dart';

/// A single entry in the "Latest Love Letter" board.
///
/// Shows who it's from, roughly when it was left, and the note itself,
/// styled a little like a small sticky note / letter rather than a
/// plain list row.
class MessageCard extends StatelessWidget {
  final String label; // e.g. "Aly" or "Ranjo"
  final Message? message;
  final bool isMe;

  const MessageCard({
    super.key,
    required this.label,
    required this.message,
    required this.isMe,
  });

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '${m}m ago';
    }
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasMessage = message != null;

    final accent = hasMessage
        ? (isMe ? scheme.primary : scheme.secondary)
        : scheme.outlineVariant;
    final fg = hasMessage
        ? (isMe ? scheme.onPrimaryContainer : scheme.onSecondaryContainer)
        : scheme.outline;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(message?.text ?? 'empty-$label'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 8, 0, 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: accent,
                  child: Text(
                    label.isNotEmpty ? label[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hasMessage
                          ? (isMe ? scheme.onPrimary : scheme.onSecondary)
                          : scheme.surface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMe ? '$label · You' : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (hasMessage) ...[
                  const SizedBox(width: 6),
                  Text(
                    _relativeTime(message!.updatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                message?.text ?? 'No message yet',
                style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
