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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isMe ? Colors.pink.shade50 : Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message?.text ?? 'No message yet',
              style: TextStyle(
                fontSize: 15,
                fontStyle: message == null
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: message == null ? Colors.grey : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
