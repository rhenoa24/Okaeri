import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../models/calendar_note.dart';
import '../../models/plan.dart';
import '../../services/message_service.dart';
import '../../services/user_service.dart';
import '../../services/calendar_service.dart';
import '../message_board/message_board_screen.dart';
import '../calendar/events_screen.dart';
import '../calendar/plans_screen.dart';

class HomeScreen extends StatefulWidget {
  final String coupleId;
  const HomeScreen({super.key, required this.coupleId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MessageService _messageService = MessageService();
  final UserService _userService = UserService();
  final CalendarService _calendarService = CalendarService();

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

          _SectionCard(
            icon: Icons.alarm,
            title: 'Upcoming Plans',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlansScreen(coupleId: widget.coupleId),
                ),
              );
            },
            child: StreamBuilder<List<Plan>>(
              stream: _calendarService.watchUpcomingPlans(
                widget.coupleId,
                limit: 3,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const _EmptyState(text: 'Nothing planned yet 📅');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items
                      .map((item) => _PlanPreviewRow(item: item))
                      .toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _SectionCard(
            icon: Icons.favorite_border,
            title: 'Important Dates',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventsScreen(coupleId: widget.coupleId),
                ),
              );
            },
            child: StreamBuilder<List<CalendarNote>>(
              stream: _calendarService.watchAllNotes(widget.coupleId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                final upcoming =
                    snapshot.data!
                        .where((n) => n.isImportant)
                        .map((n) => (note: n, next: n.nextOccurrence(now)))
                        .where((e) => !e.next.isBefore(today))
                        .toList()
                      ..sort((a, b) => a.next.compareTo(b.next));

                if (upcoming.isEmpty) {
                  return const _EmptyState(
                    text: 'No important dates marked yet',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: upcoming
                      .take(3)
                      .map(
                        (e) => _ImportantDatePreviewRow(
                          note: e.note,
                          occurrence: e.next,
                        ),
                      )
                      .toList(),
                );
              },
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

class _PlanPreviewRow extends StatelessWidget {
  final Plan item;
  const _PlanPreviewRow({required this.item});

  // A plan can have several timetable entries now; the preview just shows
  // the earliest one, if any have been added yet.
  String get _displayTime {
    final entries = item.sortedTimetable;
    if (entries.isEmpty) return '';
    final hour = int.parse(entries.first.time.split(':')[0]);
    final minute = entries.first.time.split(':')[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:$minute $period';
  }

  DateTime get _date {
    final parts = item.date.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  @override
  Widget build(BuildContext context) {
    final time = _displayTime;
    final dateLabel = time.isEmpty
        ? DateFormat('MMM d').format(_date)
        : '${DateFormat('MMM d').format(_date)}, $time';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dateLabel,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ImportantDatePreviewRow extends StatelessWidget {
  final CalendarNote note;
  final DateTime occurrence;
  const _ImportantDatePreviewRow({
    required this.note,
    required this.occurrence,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('MMM d').format(occurrence),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
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
