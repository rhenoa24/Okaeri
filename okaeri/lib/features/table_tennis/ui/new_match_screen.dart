import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/user/user_service.dart';
import '../../pairing/data/couple_service.dart';
import '../data/match.dart';
import '../data/match_service.dart';
import 'live_match_screen.dart';

/// One player's editable slot. [uid]/[origName] let us keep the uid only
/// while the name is unchanged; if you rename a slot to a friend, uid
/// becomes null (a guest).
class _Slot {
  final ctrl = TextEditingController();
  String? uid;
  String origName = '';
}

class NewMatchScreen extends StatefulWidget {
  const NewMatchScreen({super.key, required this.coupleId, required this.uid});

  final String coupleId;
  final String uid;

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  final _a = _Slot();
  final _b = _Slot();
  final _noteCtrl = TextEditingController();

  bool _loading = true;
  bool _starting = false;
  int _bestOf = 3;
  String _first = 'A'; // 'A' | 'B' | 'R' (random)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _a.ctrl.dispose();
    _b.ctrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userService = UserService();
    String? partnerUid;
    try {
      final couple = await CoupleService().watchCouple(widget.coupleId).first;
      final members = List<String>.from(couple?['members'] ?? []);
      partnerUid = members.where((u) => u != widget.uid).firstOrNull;
    } catch (_) {}

    final myName = await userService.getDisplayName(widget.uid);
    final partnerName = partnerUid == null
        ? 'Player 2'
        : await userService.getDisplayName(partnerUid);

    if (!mounted) return;
    setState(() {
      _a
        ..uid = widget.uid
        ..origName = myName
        ..ctrl.text = myName;
      _b
        ..uid = partnerUid
        ..origName = partnerName
        ..ctrl.text = partnerName;
      _loading = false;
    });
  }

  void _swap() {
    setState(() {
      final text = _a.ctrl.text;
      final uid = _a.uid;
      final orig = _a.origName;
      _a.ctrl.text = _b.ctrl.text;
      _a.uid = _b.uid;
      _a.origName = _b.origName;
      _b.ctrl.text = text;
      _b.uid = uid;
      _b.origName = orig;
    });
  }

  MatchPlayer _playerFrom(_Slot slot, String fallback) {
    final name = slot.ctrl.text.trim();
    if (name.isEmpty) return MatchPlayer(name: fallback);
    return MatchPlayer(
      name: name,
      uid: name == slot.origName ? slot.uid : null,
    );
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final first = _first == 'R' ? (Random().nextBool() ? 'A' : 'B') : _first;

    final match = await MatchService().createMatch(
      coupleId: widget.coupleId,
      playerA: _playerFrom(_a, 'Player 1'),
      playerB: _playerFrom(_b, 'Player 2'),
      bestOf: _bestOf,
      firstServer: first,
      createdBy: widget.uid,
      note: _noteCtrl.text.trim(),
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveMatchScreen(
          coupleId: widget.coupleId,
          uid: widget.uid,
          match: match,
        ),
      ),
    );
  }

  String _label(_Slot slot, String fallback) {
    final t = slot.ctrl.text.trim();
    return t.isEmpty ? fallback : t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New match')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _section('Players'),

                TextField(
                  controller: _b.ctrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Top of the screen',
                    prefixIcon: Icon(Icons.arrow_upward),
                    border: OutlineInputBorder(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: IconButton.filledTonal(
                      tooltip: 'Swap sides',
                      onPressed: _swap,
                      icon: const Icon(Icons.swap_vert),
                    ),
                  ),
                ),
                TextField(
                  controller: _a.ctrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Bottom of the screen',
                    prefixIcon: Icon(Icons.arrow_downward),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 6),
                Text(
                  'Lay the phone flat under the net. The top half is '
                  'upside-down so both of you can read it.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 28),
                _section('Best of'),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 3, label: Text('3')),
                      ButtonSegment(value: 5, label: Text('5')),
                      ButtonSegment(value: 7, label: Text('7')),
                    ],
                    selected: {_bestOf},
                    onSelectionChanged: (s) =>
                        setState(() => _bestOf = s.first),
                  ),
                ),
                const SizedBox(height: 28),
                _section('Who serves first?'),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'A',
                        label: Text(
                          _label(_a, 'Player 1'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ButtonSegment(
                        value: 'B',
                        label: Text(
                          _label(_b, 'Player 2'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const ButtonSegment(
                        value: 'R',
                        label: Text('Random'),
                        icon: Icon(Icons.casino_outlined),
                      ),
                    ],
                    selected: {_first},
                    onSelectionChanged: (s) => setState(() => _first = s.first),
                  ),
                ),
                const SizedBox(height: 28),
                _section('Stakes (optional)'),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Loser buys ramen 🍜',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  onPressed: _starting ? null : _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Start match',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
