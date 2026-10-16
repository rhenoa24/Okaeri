import 'package:flutter/material.dart';

import '../data/game_state.dart';

/// One game as a mini rally chart: top lane = A's points, bottom lane = B's.
class GamePointDots extends StatelessWidget {
  const GamePointDots({
    super.key,
    required this.log,
    required this.firstServer,
  });

  final String log;
  final String firstServer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = GameState(log, firstServer: firstServer);

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            '${state.a}–${state.b}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 20,
            child: CustomPaint(
              painter: _DotsPainter(
                log: log,
                colorA: cs.primary,
                colorB: cs.tertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.log, required this.colorA, required this.colorB});

  final String log;
  final Color colorA;
  final Color colorB;

  @override
  void paint(Canvas canvas, Size size) {
    final n = log.length;
    if (n == 0) return;

    // Dots spread out up to 12px apart, then squeeze for long deuce games.
    const margin = 4.0;
    final step = n == 1
        ? 0.0
        : ((size.width - margin * 2) / (n - 1)).clamp(0.0, 12.0);
    final r = n == 1 ? 4.0 : (step / 2.2).clamp(1.5, 4.0);

    final paintA = Paint()..color = colorA;
    final paintB = Paint()..color = colorB;

    for (var i = 0; i < n; i++) {
      final isA = log[i] == 'A';
      canvas.drawCircle(
        Offset(margin + i * step, isA ? r : size.height - r),
        r,
        isA ? paintA : paintB,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.log != log || old.colorA != colorA || old.colorB != colorB;
}
