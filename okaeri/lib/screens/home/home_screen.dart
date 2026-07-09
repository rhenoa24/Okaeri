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
import '../calendar/events_screen.dart';
import '../calendar/plans_screen.dart';
import '../../widgets/message_card.dart';

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

  final TextEditingController _replyController = TextEditingController();
  bool _showReplyField = false;

  void _sendQuickMessage() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    await _messageService.setMessage(
      coupleId: widget.coupleId,
      partnerId: myId,
      authorName: myName,
      text: text,
    );
    _replyController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _showReplyField = false);
  }

  List<Widget> _buildMessagePreviewCards() {
    final entries = <_HomeMessageEntry>[
      _HomeMessageEntry(name: myName, message: _myMessage, isMe: true),
      _HomeMessageEntry(
        name: partnerName,
        message: _partnerMessage,
        isMe: false,
      ),
    ];

    final visible = entries.where((e) => e.message != null).toList()
      ..sort((a, b) => a.message!.updatedAt.compareTo(b.message!.updatedAt));

    return visible
        .map(
          (e) => MessageCard(label: e.name, message: e.message, isMe: e.isMe),
        )
        .toList();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _mySub?.cancel();
    _partnerSub?.cancel();
    _myNameSub?.cancel();
    _partnerNameSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        titleSpacing: 16,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome home!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              (myName.isEmpty || partnerName.isEmpty)
                  ? 'Let\'s get started ❤'
                  : '$myName ❤ $partnerName',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.all(16),
              trailing: const SizedBox.shrink(),
              onExpansionChanged: (expanded) {
                setState(() => _showReplyField = expanded);
              },
              title: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Latest Love Letter',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        // const Spacer(),
                        // AnimatedRotation(
                        //   turns: _showReplyField ? 0.5 : 0,
                        //   duration: const Duration(milliseconds: 200),
                        //   child: Icon(
                        //     Icons.keyboard_arrow_down,
                        //     color: Theme.of(context).colorScheme.outlineVariant,
                        //   ),
                        // ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final cards = _buildMessagePreviewCards();
                        if (cards.isEmpty) {
                          return const _EmptyState(
                            text: 'No messages yet — write the first one!',
                          );
                        }
                        return Column(
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              cards[i],
                              if (i != cards.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              children: [
                Divider(
                  height: 24,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Leave a little note...',
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.4),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _sendQuickMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sendQuickMessage,
                      icon: const Icon(Icons.send, size: 18),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
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
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
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
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
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
      style: TextStyle(
        color: Theme.of(context).colorScheme.outline,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _HomeMessageEntry {
  final String name;
  final Message? message;
  final bool isMe;

  _HomeMessageEntry({
    required this.name,
    required this.message,
    required this.isMe,
  });
}
