import 'package:flutter/material.dart';

import 'match_history_screen.dart';
import 'new_match_screen.dart';

/// Entry point for the feature, opened from the More screen.
class OurScoreboardScreen extends StatelessWidget {
  const OurScoreboardScreen({
    super.key,
    required this.coupleId,
    required this.uid,
  });

  final String coupleId;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Our Scoreboard')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.sports_tennis, size: 72, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                'Table Tennis',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Keep score. Keep bragging rights.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'Start a New Match',
                  style: TextStyle(fontSize: 18),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NewMatchScreen(coupleId: coupleId, uid: uid),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                ),
                icon: const Icon(Icons.history),
                label: const Text(
                  'Match History',
                  style: TextStyle(fontSize: 18),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MatchHistoryScreen(coupleId: coupleId, uid: uid),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
