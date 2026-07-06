import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  late final String myId;
  late final String myName;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    myId = user.uid;
    myName = user.email!.split('@')[0]; // temporary display name from email
  }

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
      appBar: AppBar(
        title: const Text('Message Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
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
