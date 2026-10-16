import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../bloc/match_controller.dart';
import '../data/game_state.dart';
import '../data/match.dart';
import '../data/match_service.dart';

/// Tabletop scoreboard. Lay the phone flat under the net:
///  - the bottom half belongs to the player at the bottom,
///  - the top half is rotated 180° so the player on the other side reads it
///    right-side up (toggle in the menu),
///  - tap your half to score a point.
class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({
    super.key,
    required this.coupleId,
    required this.uid,
    required this.match,
  });

  final String coupleId;
  final String uid;
  final TtMatch match;

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  late final MatchController _c;
  final _service = MatchService();
  bool _faceToFace = true;

  @override
  void initState() {
    super.initState();
    _c = MatchController(coupleId: widget.coupleId, match: widget.match);
    WakelockPlus.enable(); // keep the screen on while playing
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final m = _c.match;
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _half(_c.topSide, rotate: _faceToFace),
                    _centerStrip(context),
                    _half(_c.bottomSide, rotate: false),
                  ],
                ),
                if (_c.waitingForNextGame) _gameOverOverlay(context),
                if (m.isFinished) _matchOverOverlay(context),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- player halves ----------------------------------------------------

  Widget _half(String side, {required bool rotate}) {
    final cs = Theme.of(context).colorScheme;
    final m = _c.match;
    final g = _c.game;

    final serving = !g.isOver && !m.isFinished && g.server == side;
    final wins = side == 'A' ? m.gamesWonA : m.gamesWonB;
    final base = side == 'A' ? cs.primaryContainer : cs.tertiaryContainer;
    final onBase = side == 'A' ? cs.onPrimaryContainer : cs.onTertiaryContainer;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          m.nameOf(side),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: onBase,
          ),
        ),
        const SizedBox(height: 6),
        _GameDots(won: wins, needed: m.winsNeeded, color: onBase),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${g.scoreOf(side)}',
            style: TextStyle(
              fontSize: 150,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: onBase,
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: serving
              ? Chip(
                  avatar: const Icon(Icons.sports_tennis, size: 18),
                  label: const Text('Serving'),
                  backgroundColor: onBase.withValues(alpha: .15),
                  side: BorderSide.none,
                )
              : (g.hasGamePoint(side) && !m.isFinished
                    ? Text(
                        'Game point',
                        style: TextStyle(
                          color: onBase,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null),
        ),
      ],
    );

    if (rotate) content = RotatedBox(quarterTurns: 2, child: content);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _c.addPoint(side),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: serving ? base : base.withValues(alpha: .55),
            border: serving ? Border.all(color: onBase, width: 5) : null,
          ),
          child: content,
        ),
      ),
    );
  }

  // ---- middle strip -----------------------------------------------------

  Widget _centerStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = _c.match;

    return Container(
      height: 76,
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Undo last point',
            iconSize: 30,
            onPressed: _c.canUndo ? _c.undo : null,
            icon: const Icon(Icons.undo),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${m.playerA.name}  ${m.gamesWonA} – ${m.gamesWonB}  ${m.playerB.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (_c.showSwitchEnds)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🔄 Switch ends!',
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Text(
                    'Game ${_c.gameIndex + 1} · Best of ${m.bestOf}'
                    '${_c.isDecidingGame ? ' · Deciding game' : ''}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Menu',
            iconSize: 30,
            onPressed: _openMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }

  // ---- overlays ---------------------------------------------------------

  Widget _gameOverOverlay(BuildContext context) {
    final m = _c.match;
    final g = _c.game;
    final winnerName = m.nameOf(g.winner!);
    final nextServer = m.nameOf(GameState.other(_c.currentRecord.firstServer));

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Game ${_c.gameIndex + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$winnerName wins ${g.a}–${g.b}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text('🔄 Switch ends'),
                  const SizedBox(height: 4),
                  Text('$nextServer serves first next game'),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _c.nextGame,
                    child: Text('Start game ${_c.gameIndex + 2}'),
                  ),
                  TextButton(
                    onPressed: _c.undo,
                    child: const Text('Undo last point'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _matchOverOverlay(BuildContext context) {
    final m = _c.match;
    final winnerName = m.nameOf(m.winner!);
    final scores = m.games.map((g) => '${g.state.a}–${g.state.b}').join('   ');

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    '$winnerName wins!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${m.gamesWonA} – ${m.gamesWonB} in games',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(scores),
                  if (m.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('💬 ${m.note}', textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _rematch,
                    icon: const Icon(Icons.replay),
                    label: const Text('Rematch'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                  TextButton(
                    onPressed: _c.undo,
                    child: const Text('Undo last point'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rematch() async {
    final m = _c.match;
    // The loser-of-the-coin-toss idea: whoever served first last time
    // receives first this time.
    final first = GameState.other(m.games.first.firstServer);
    final next = await _service.createMatch(
      coupleId: widget.coupleId,
      playerA: m.playerA,
      playerB: m.playerB,
      bestOf: m.bestOf,
      firstServer: first,
      createdBy: widget.uid,
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LiveMatchScreen(
          coupleId: widget.coupleId,
          uid: widget.uid,
          match: next,
        ),
      ),
    );
  }

  // ---- menu -------------------------------------------------------------

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.screen_rotation_alt),
                title: const Text('Face-to-face mode'),
                subtitle: const Text('Flip the top half for the other player'),
                value: _faceToFace,
                onChanged: (v) {
                  setState(() => _faceToFace = v);
                  setSheetState(() {});
                },
              ),
              if (_c.currentRecord.log.isEmpty && !_c.matchFinished)
                ListTile(
                  leading: const Icon(Icons.sports_tennis),
                  title: const Text('Change who serves first'),
                  subtitle: Text(
                    'Now: ${_c.match.nameOf(_c.currentRecord.firstServer)}',
                  ),
                  onTap: () {
                    _c.swapFirstServer();
                    Navigator.pop(sheetContext);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Stakes / note'),
                subtitle: _c.match.note.isEmpty ? null : Text(_c.match.note),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editNote();
                },
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Leave (keep match saved)'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pop(this.context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete this match',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editNote() async {
    final ctrl = TextEditingController(text: _c.match.note);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stakes / note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Loser buys ramen 🍜'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) _c.setNote(result);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this match?'),
        content: const Text('It will be removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _service.deleteMatch(widget.coupleId, _c.match.id);
    if (mounted) Navigator.pop(context);
  }
}

/// Small dots showing games won toward the match win.
class _GameDots extends StatelessWidget {
  const _GameDots({
    required this.won,
    required this.needed,
    required this.color,
  });

  final int won;
  final int needed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(needed, (i) {
        final filled = i < won;
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
        );
      }),
    );
  }
}
