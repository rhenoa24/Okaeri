/// Pure scoring logic for ONE game of table tennis (ITTF rules).
///
/// The game is stored as a point log, e.g. "AABABBA", where each character
/// is the side that won that point. Everything else (score, server, winner)
/// is derived from it, so they can never drift out of sync and undo is
/// just "remove the last character".
class GameState {
  const GameState(this.log, {required this.firstServer});

  /// Who scored each point, in order. 'A' or 'B'.
  final String log;

  /// Who served the first point of this game. 'A' or 'B'.
  final String firstServer;

  static String other(String side) => side == 'A' ? 'B' : 'A';

  int get a => _count('A');
  int get b => _count('B');
  int get total => log.length;

  int scoreOf(String side) => side == 'A' ? a : b;

  int _count(String side) => log.split('').where((c) => c == side).length;

  /// Both players at 10+ → serve changes every point.
  bool get isDeuce => a >= 10 && b >= 10;

  /// Serve changes every 2 points, but every 1 point once deuce starts.
  String get server {
    final flips = isDeuce ? 10 + (total - 20) : total ~/ 2;
    return flips.isEven ? firstServer : other(firstServer);
  }

  /// First to 11, win by 2.
  bool get isOver => (a >= 11 || b >= 11) && (a - b).abs() >= 2;

  String? get winner => !isOver ? null : (a > b ? 'A' : 'B');

  /// True if [side] wins the game by scoring the next point.
  bool hasGamePoint(String side) {
    if (isOver) return false;
    final mine = scoreOf(side);
    final theirs = scoreOf(other(side));
    return mine >= 10 && mine > theirs;
  }

  String? get lastScorer => log.isEmpty ? null : log[log.length - 1];
}
