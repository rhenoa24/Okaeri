import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';
import '../../services/user_service.dart';
import '../message_board/message_board_screen.dart';

class HomeScreen extends StatefulWidget {
  final String coupleId;
  const HomeScreen({super.key, required this.coupleId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MessageService _messageService = MessageService();
  final UserService _userService = UserService();

  late final String myId;
  String myName = '';
  String partnerName = '';
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
    _myNameSub = _userService.watchDisplayName(myId).listen((name) {
      setState(() => myName = name);
    });

    _mySub = _messageService.watchMessage(widget.coupleId, myId).listen((msg) {
      setState(() => _myMessage = msg);
    });

    final coupleDoc = await FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .get();
    final members = List<String>.from(coupleDoc.data()?['members'] ?? []);
    partnerId = members.firstWhere((id) => id != myId, orElse: () => '');

    if (partnerId != null && partnerId!.isNotEmpty) {
      _partnerNameSub = _userService.watchDisplayName(partnerId!).listen((
        name,
      ) {
        setState(() => partnerName = name);
      });
      _partnerSub = _messageService
          .watchMessage(widget.coupleId, partnerId!)
          .listen((msg) {
            setState(() => _partnerMessage = msg);
          });
    }
  }

  @override
  void dispose() {
    _mySub?.cancel();
    _partnerSub?.cancel();
    _myNameSub?.cancel();
    _partnerNameSub?.cancel();
    super.dispose();
  }

  // Whichever message was updated most recently, across both partners
  Message? get _latestMessage {
    if (_myMessage == null) return _partnerMessage;
    if (_partnerMessage == null) return _myMessage;
    return _myMessage!.updatedAt.isAfter(_partnerMessage!.updatedAt)
        ? _myMessage
        : _partnerMessage;
  }

  @override
  Widget build(BuildContext context) {
    final names = (myName.isEmpty || partnerName.isEmpty)
        ? 'Welcome home'
        : 'Welcome home,\n$myName ❤ $partnerName';

    return Scaffold(
      appBar: AppBar(title: const Text('🏡 Okaeri'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            names,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),

          _SectionCard(
            icon: Icons.mail_outline,
            title: 'Latest Love Letter',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MessageBoardScreen(coupleId: widget.coupleId),
                ),
              );
            },
            child: _latestMessage == null
                ? const _EmptyState(
                    text: 'No messages yet — write the first one!',
                  )
                : _LatestMessagePreview(message: _latestMessage!),
          ),
          const SizedBox(height: 16),

          const _SectionCard(
            icon: Icons.event_note_outlined,
            title: 'Upcoming Plans',
            child: _EmptyState(
              text: 'Your planned dates will show up here soon 📅',
            ),
          ),
          const SizedBox(height: 16),

          const _SectionCard(
            icon: Icons.star_border,
            title: 'Important Dates',
            child: _EmptyState(
              text: 'Pinned & important dates will show up here ⭐',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestMessagePreview extends StatelessWidget {
  final Message message;
  const _LatestMessagePreview({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.authorName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
    );
  }
}
