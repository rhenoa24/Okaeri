import 'package:flutter/material.dart';

import '../data/match.dart';
import '../data/match_service.dart';
import 'live_match_screen.dart';
import 'match_card.dart';

class MatchHistoryScreen extends StatelessWidget {
  MatchHistoryScreen({super.key, required this.coupleId, required this.uid});

  final String coupleId;
  final String uid;
  final _service = MatchService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match History')),
      body: StreamBuilder<List<TtMatch>>(
        stream: _service.watchMatches(coupleId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load matches'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No matches yet.\nStart one and it will show up here 🏓',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _HeadToHead(matches: matches),
              for (final m in matches)
                MatchCard(
                  match: m,
                  onTap: () => m.isFinished
                      ? _showDetails(context, m)
                      : Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveMatchScreen(
                              coupleId: coupleId,
                              uid: uid,
                              match: m,
                            ),
                          ),
                        ),
                  onLongPress: () => _confirmDelete(context, m),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TtMatch m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this match?'),
        content: Text('${m.playerA.name} vs ${m.playerB.name}'),
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
    if (ok == true) _service.deleteMatch(coupleId, m.id);
  }

  void _showDetails(BuildContext context, TtMatch m) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.nameOf(m.winner!)} won ${m.gamesWonA > m.gamesWonB ? m.gamesWonA : m.gamesWonB}–${m.gamesWonA > m.gamesWonB ? m.gamesWonB : m.gamesWonA}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(formatMatchDate(m.createdAt)),
              if (m.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('💬 ${m.note}'),
              ],
              const SizedBox(height: 16),
              for (var i = 0; i < m.games.length; i++)
                if (m.games[i].log.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 70, child: Text('Game ${i + 1}')),
                        Text(
                          '${m.playerA.name} ${m.games[i].state.a} – ${m.games[i].state.b} ${m.playerB.name}',
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Head-to-head record + streak for the pair from the most recent finished
/// match. Players are matched by uid when present, otherwise by name.
class _HeadToHead extends StatelessWidget {
  const _HeadToHead({required this.matches});

  final List<TtMatch> matches; // newest first

  static String _key(MatchPlayer p) => p.uid ?? p.name.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final finished = matches.where((m) => m.isFinished).toList();
    if (finished.isEmpty) return const SizedBox.shrink();

    final ref = finished.first;
    final k1 = _key(ref.playerA);
    final k2 = _key(ref.playerB);

    final pair = finished.where((m) {
      final ks = {_key(m.playerA), _key(m.playerB)};
      return ks.length == 2 && ks.contains(k1) && ks.contains(k2);
    }).toList();

    String winnerKey(TtMatch m) =>
        m.winner == 'A' ? _key(m.playerA) : _key(m.playerB);

    final wins1 = pair.where((m) => winnerKey(m) == k1).length;
    final wins2 = pair.length - wins1;

    final lead = winnerKey(pair.first);
    var streak = 0;
    for (final m in pair) {
      if (winnerKey(m) == lead) {
        streak++;
      } else {
        break;
      }
    }
    final leadName = lead == k1 ? ref.playerA.name : ref.playerB.name;

    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              'Head to head',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${ref.playerA.name}  $wins1 – $wins2  ${ref.playerB.name}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onPrimaryContainer,
              ),
            ),
            if (streak >= 2) ...[
              const SizedBox(height: 6),
              Text(
                '🔥 $leadName is on a $streak-match streak',
                style: TextStyle(color: cs.onPrimaryContainer),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
