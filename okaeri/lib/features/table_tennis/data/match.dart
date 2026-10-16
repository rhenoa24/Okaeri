import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_state.dart';

/// Named TtMatch because `Match` already exists in dart:core (RegExp).

/// A player snapshot stored on the match. [uid] is null for guests, and old
/// matches never change when someone renames themselves later.
class MatchPlayer {
  const MatchPlayer({required this.name, this.uid});

  final String name;
  final String? uid;

  Map<String, dynamic> toMap() => {'name': name, 'uid': uid};

  factory MatchPlayer.fromMap(Map<String, dynamic> map) => MatchPlayer(
    name: (map['name'] as String?) ?? 'Player',
    uid: map['uid'] as String?,
  );
}

/// One game inside a match: just the point log + who served first.
class GameRecord {
  const GameRecord({required this.log, required this.firstServer});

  final String log;
  final String firstServer;

  GameState get state => GameState(log, firstServer: firstServer);

  Map<String, dynamic> toMap() => {'log': log, 'firstServer': firstServer};

  factory GameRecord.fromMap(Map<String, dynamic> map) => GameRecord(
    log: (map['log'] as String?) ?? '',
    firstServer: (map['firstServer'] as String?) ?? 'A',
  );
}

class TtMatch {
  const TtMatch({
    required this.id,
    required this.playerA,
    required this.playerB,
    required this.bestOf,
    required this.games,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.note = '',
    this.finishedAt,
  });

  final String id;
  final MatchPlayer playerA; // starts at the bottom of the screen
  final MatchPlayer playerB; // starts at the top of the screen
  final int bestOf;
  final List<GameRecord> games;
  final String status; // 'inProgress' | 'finished'
  final String note;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? finishedAt;

  int get winsNeeded => bestOf ~/ 2 + 1;

  int get gamesWonA => games.where((g) => g.state.winner == 'A').length;
  int get gamesWonB => games.where((g) => g.state.winner == 'B').length;

  /// Match winner, derived from the games. Null while in progress.
  String? get winner {
    if (gamesWonA >= winsNeeded) return 'A';
    if (gamesWonB >= winsNeeded) return 'B';
    return null;
  }

  bool get isFinished => status == 'finished';

  String nameOf(String side) => side == 'A' ? playerA.name : playerB.name;

  TtMatch copyWith({
    List<GameRecord>? games,
    String? status,
    String? note,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
  }) {
    return TtMatch(
      id: id,
      playerA: playerA,
      playerB: playerB,
      bestOf: bestOf,
      games: games ?? this.games,
      status: status ?? this.status,
      note: note ?? this.note,
      createdBy: createdBy,
      createdAt: createdAt,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
    );
  }

  Map<String, dynamic> toMap() => {
    'playerA': playerA.toMap(),
    'playerB': playerB.toMap(),
    'bestOf': bestOf,
    'games': games.map((g) => g.toMap()).toList(),
    'status': status,
    'winner': winner,
    'note': note,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'finishedAt': finishedAt == null ? null : Timestamp.fromDate(finishedAt!),
  };

  factory TtMatch.fromMap(String id, Map<String, dynamic> map) => TtMatch(
    id: id,
    playerA: MatchPlayer.fromMap(
      Map<String, dynamic>.from(map['playerA'] as Map? ?? {}),
    ),
    playerB: MatchPlayer.fromMap(
      Map<String, dynamic>.from(map['playerB'] as Map? ?? {}),
    ),
    bestOf: (map['bestOf'] as int?) ?? 3,
    games: (map['games'] as List? ?? [])
        .map((g) => GameRecord.fromMap(Map<String, dynamic>.from(g as Map)))
        .toList(),
    status: (map['status'] as String?) ?? 'inProgress',
    note: (map['note'] as String?) ?? '',
    createdBy: (map['createdBy'] as String?) ?? '',
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    finishedAt: (map['finishedAt'] as Timestamp?)?.toDate(),
  );
}
