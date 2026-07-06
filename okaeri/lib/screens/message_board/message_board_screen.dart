import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';
import '../../widgets/message_cart.dart';

class MessageBoardScreen extends StatefulWidget {
  const MessageBoardScreen({super.key});

  @override
  State<MessageBoardScreen> createState() => _MessageBoardScreenState();
}

class _MessageBoardScreenState extends State<MessageBoardScreen> {
  final MessageService _service = MessageService();
  final TextEditingController _controller = TextEditingController();

  // Temporary fixed IDs until real auth is wired in
  final String myId = 'partner1';
  final String partnerId = 'partner2';
  final String myName = 'Aly'; // change to your name for testing

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    await _service.setMessage(
      partnerId: myId,
      authorName: myName,
      text: _controller.text.trim(),
    );

    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Board')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Partner's message (read-only)
                StreamBuilder<Message?>(
                  stream: _service.watchMessage(partnerId),
                  builder: (context, snapshot) {
                    return MessageCard(
                      label: 'Partner',
                      message: snapshot.data,
                      isMe: false,
                    );
                  },
                ),
                // My message (read-only display of what I last sent)
                StreamBuilder<Message?>(
                  stream: _service.watchMessage(myId),
                  builder: (context, snapshot) {
                    return MessageCard(
                      label: myName,
                      message: snapshot.data,
                      isMe: true,
                    );
                  },
                ),
              ],
            ),
          ),
          // Input area
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Leave a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
