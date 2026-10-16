import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'match.dart';

class MatchService {
  CollectionReference<Map<String, dynamic>> _ref(String coupleId) =>
      FirebaseFirestore.instance
          .collection('couples')
          .doc(coupleId)
          .collection('matches');

  /// Newest first.
  Stream<List<TtMatch>> watchMatches(String coupleId) {
    return _ref(coupleId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TtMatch.fromMap(d.id, d.data())).toList(),
        );
  }

  /// Creates the match doc. The Firestore write is NOT awaited on purpose:
  /// with offline persistence a write only completes once the server
  /// acknowledges it, and we don't want the scoreboard to hang with a bad
  /// connection. The local cache updates immediately either way.
  Future<TtMatch> createMatch({
    required String coupleId,
    required MatchPlayer playerA,
    required MatchPlayer playerB,
    required int bestOf,
    required String firstServer,
    required String createdBy,
    String note = '',
  }) async {
    final doc = _ref(coupleId).doc();
    final match = TtMatch(
      id: doc.id,
      playerA: playerA,
      playerB: playerB,
      bestOf: bestOf,
      games: [GameRecord(log: '', firstServer: firstServer)],
      status: 'inProgress',
      note: note,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    unawaited(_guard(() => doc.set(match.toMap())));
    return match;
  }

  /// Called after every point / undo / next game.
  Future<void> saveProgress(String coupleId, TtMatch match) {
    return _guard(
      () => _ref(coupleId).doc(match.id).update({
        'games': match.games.map((g) => g.toMap()).toList(),
        'status': match.status,
        'winner': match.winner,
        'finishedAt': match.finishedAt == null
            ? null
            : Timestamp.fromDate(match.finishedAt!),
      }),
    );
  }

  Future<void> updateNote(String coupleId, String matchId, String note) {
    return _guard(() => _ref(coupleId).doc(matchId).update({'note': note}));
  }

  Future<void> deleteMatch(String coupleId, String matchId) {
    return _guard(() => _ref(coupleId).doc(matchId).delete());
  }

  /// A failed save shouldn't crash or block scoring; log and move on.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('MatchService error: $e');
    }
  }
}
