import 'package:flutter/material.dart';

import '../data/match.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatMatchDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.onTap,
    this.onLongPress,
  });

  final TtMatch match;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final winner = match.winner;
    final scores = match.games
        .where((g) => g.log.isNotEmpty)
        .map((g) => '${g.state.a}–${g.state.b}')
        .join('  ·  ');

    TextStyle nameStyle(String side) => TextStyle(
      fontSize: 16,
      fontWeight: winner == side ? FontWeight.w800 : FontWeight.w400,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    formatMatchDate(match.createdAt),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                  const Spacer(),
                  if (!match.isFinished)
                    Chip(
                      label: const Text('In progress · tap to resume'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cs.secondaryContainer,
                      side: BorderSide.none,
                    )
                  else
                    Text(
                      'Best of ${match.bestOf}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.playerA.name,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle('A'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '${match.gamesWonA} – ${match.gamesWonB}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      match.playerB.name,
                      overflow: TextOverflow.ellipsis,
                      style: nameStyle('B'),
                    ),
                  ),
                ],
              ),
              if (scores.isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    scores,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ],
              if (match.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(child: Text('💬 ${match.note}')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
