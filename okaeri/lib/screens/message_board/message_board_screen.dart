import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';
import '../../services/user_service.dart';
import '../../widgets/message_card.dart';

class MessageBoardScreen extends StatefulWidget {
  final String coupleId;
  const MessageBoardScreen({super.key, required this.coupleId});

  @override
  State<MessageBoardScreen> createState() => _MessageBoardScreenState();
}

class _MessageBoardScreenState extends State<MessageBoardScreen> {
  final MessageService _service = MessageService();
  final UserService _userService = UserService();
  final TextEditingController _controller = TextEditingController();

  late final String myId;
  String myName = '';
  String partnerName = 'Partner';
  String? partnerId;

  Message? _myMessage;
  Message? _partnerMessage;

  StreamSubscription<Message?>? _mySub;
  StreamSubscription<Message?>? _partnerSub;
  StreamSubscription<String>? _myNameSub;
  StreamSubscription<String>? _partnerNameSub;

  @override
  void initState() {
    super.initState();
    myId = FirebaseAuth.instance.currentUser!.uid;
    _init();
  }

  Future<void> _init() async {
    // Live name stream for myself
    _myNameSub = _userService.watchDisplayName(myId).listen((name) {
      setState(() => myName = name);
    });

    // Live message stream for myself
    _mySub = _service.watchMessage(widget.coupleId, myId).listen((msg) {
      setState(() => _myMessage = msg);
    });

    // Find partner uid from the couple doc
    final coupleDoc = await FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .get();
    final members = List<String>.from(coupleDoc.data()?['members'] ?? []);
    partnerId = members.firstWhere((id) => id != myId, orElse: () => '');

    if (partnerId != null && partnerId!.isNotEmpty) {
      // Live name stream for partner
      _partnerNameSub = _userService.watchDisplayName(partnerId!).listen((
        name,
      ) {
        setState(() => partnerName = name);
      });

      // Live message stream for partner
      _partnerSub = _service.watchMessage(widget.coupleId, partnerId!).listen((
        msg,
      ) {
        setState(() => _partnerMessage = msg);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _mySub?.cancel();
    _partnerSub?.cancel();
    _myNameSub?.cancel();
    _partnerNameSub?.cancel();
    super.dispose();
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    await _service.setMessage(
      coupleId: widget.coupleId,
      partnerId: myId,
      authorName: myName,
      text: _controller.text.trim(),
    );
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  // Order cards oldest -> newest, so the latest reply sits at the bottom
  List<Widget> _buildOrderedCards() {
    final entries = <_Entry>[
      _Entry(name: myName, message: _myMessage, isMe: true),
      _Entry(name: partnerName, message: _partnerMessage, isMe: false),
    ];

    // Remove users who don't have a message yet
    final visibleEntries = entries.where((e) => e.message != null).toList();

    visibleEntries.sort((a, b) {
      final aTime = a.message!.updatedAt;
      final bTime = b.message!.updatedAt;
      return aTime.compareTo(bTime);
    });

    return visibleEntries
        .map(
          (e) => MessageCard(label: e.name, message: e.message, isMe: e.isMe),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Board')),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                final cards = _buildOrderedCards();

                if (cards.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\nLeave one below!',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView(children: cards);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
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
          ),
        ],
      ),
    );
  }
}

class _Entry {
  final String name;
  final Message? message;
  final bool isMe;

  _Entry({required this.name, required this.message, required this.isMe});
}
