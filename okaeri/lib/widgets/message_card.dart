import 'package:flutter/material.dart';
import '../models/message.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message?.text ?? 'No message yet',
          style: TextStyle(
            fontSize: 15,
            fontStyle: message == null ? FontStyle.italic : FontStyle.normal,
            color: message == null
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
