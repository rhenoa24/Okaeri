import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/game_state.dart';
import '../data/match.dart';
import '../data/match_service.dart';

/// Drives a live match. Uses ChangeNotifier so no new dependency is needed;
/// if you'd rather have a Cubit later, the public API maps 1:1.
class MatchController extends ChangeNotifier {
  MatchController({
    required this.coupleId,
    required TtMatch match,
    MatchService? service,
  }) : _match = match,
       _service = service ?? MatchService();

  final String coupleId;
  final MatchService _service;
  TtMatch _match;

  TtMatch get match => _match;
  GameRecord get currentRecord => _match.games.last;
  GameState get game => currentRecord.state;
  int get gameIndex => _match.games.length - 1;

  bool get matchFinished => _match.isFinished;

  /// Current game is over but the match isn't → waiting for "Next game".
  bool get waitingForNextGame => game.isOver && !matchFinished;

  bool get canUndo => !(_match.games.length == 1 && currentRecord.log.isEmpty);

  /// Is the current game the deciding one (both players one game from the
  /// match win)? Counted from games BEFORE the current one.
  bool get isDecidingGame {
    final previous = _match.games.take(_match.games.length - 1);
    final winsA = previous.where((g) => g.state.winner == 'A').length;
    final winsB = previous.where((g) => g.state.winner == 'B').length;
    final needed = _match.winsNeeded;
    return winsA == needed - 1 && winsB == needed - 1;
  }

  /// Players swap ends after every game, and again at 5 points in the
  /// deciding game.
  bool get sidesFlipped {
    final midDecidingSwap = isDecidingGame && max(game.a, game.b) >= 5;
    return gameIndex.isOdd != midDecidingSwap;
  }

  /// Which player is at the TOP of the screen right now.
  String get topSide => sidesFlipped ? 'A' : 'B';
  String get bottomSide => GameState.other(topSide);

  /// True right after someone reaches 5 in the deciding game.
  bool get showSwitchEnds {
    if (!isDecidingGame || game.isOver) return false;
    final last = game.lastScorer;
    if (last == null) return false;
    return game.scoreOf(last) == 5 && game.scoreOf(GameState.other(last)) < 5;
  }

  // ---- actions ---------------------------------------------------------

  void addPoint(String side) {
    if (matchFinished || game.isOver) return;
    final updated = GameRecord(
      log: currentRecord.log + side,
      firstServer: currentRecord.firstServer,
    );
    _commit([..._match.games.take(_match.games.length - 1), updated]);

    if (updated.state.isOver) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Removes the last point (or the empty next game, then its predecessor's
  /// last point). Also reopens a finished match.
  void undo() {
    if (!canUndo) return;
    final games = [..._match.games];
    if (games.last.log.isEmpty) games.removeLast();
    final last = games.last;
    games[games.length - 1] = GameRecord(
      log: last.log.substring(0, last.log.length - 1),
      firstServer: last.firstServer,
    );
    HapticFeedback.selectionClick();
    _commit(games);
  }

  /// Serve order alternates every game.
  void nextGame() {
    if (!waitingForNextGame) return;
    final nextFirst = GameState.other(currentRecord.firstServer);
    _commit([..._match.games, GameRecord(log: '', firstServer: nextFirst)]);
  }

  /// Only allowed before the first point of a game.
  void swapFirstServer() {
    if (currentRecord.log.isNotEmpty) return;
    final games = [..._match.games];
    games[games.length - 1] = GameRecord(
      log: '',
      firstServer: GameState.other(currentRecord.firstServer),
    );
    _commit(games);
  }

  void setNote(String note) {
    _match = _match.copyWith(note: note);
    _service.updateNote(coupleId, _match.id, note);
    notifyListeners();
  }

  // ---- internals -------------------------------------------------------

  void _commit(List<GameRecord> games) {
    var next = _match.copyWith(games: games);
    final finished = next.winner != null;
    next = next.copyWith(
      status: finished ? 'finished' : 'inProgress',
      finishedAt: finished ? (_match.finishedAt ?? DateTime.now()) : null,
      clearFinishedAt: !finished,
    );
    _match = next;
    _service.saveProgress(coupleId, next);
    notifyListeners();
  }
}
