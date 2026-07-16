import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/period_entry.dart';
import '../models/period_settings.dart';

/// Shared period tracker for a couple. Data lives under
/// couples/{coupleId}/periodTracker so both partners see the same log
/// (visible to both, same as notes with visibility: 'shared').
class PeriodService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference _entriesRef(String coupleId) => _firestore
      .collection('couples')
      .doc(coupleId)
      .collection('periodTracker');

  DocumentReference _settingsRef(String coupleId) => _firestore
      .collection('couples')
      .doc(coupleId)
      .collection('meta')
      .doc('periodSettings');

  // ---- Entries (logged cycles) ----

  Stream<List<PeriodEntry>> watchEntries(String coupleId, {int limit = 24}) {
    return _entriesRef(coupleId)
        .orderBy('startDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) =>
                    PeriodEntry.fromMap(d.id, d.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  Future<String> logPeriodStart({
    required String coupleId,
    required String startDate,
    required String loggedBy,
  }) async {
    final docRef = await _entriesRef(coupleId).add({
      'startDate': startDate,
      'endDate': null,
      'symptoms': <String>[],
      'notes': '',
      'loggedBy': loggedBy,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    return docRef.id;
  }

  Future<void> logPeriodEnd({
    required String coupleId,
    required String entryId,
    required String endDate,
  }) async {
    await _entriesRef(coupleId).doc(entryId).update({
      'endDate': endDate,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateEntry({
    required String coupleId,
    required String entryId,
    String? startDate,
    String? endDate,
    List<String>? symptoms,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (startDate != null) data['startDate'] = startDate;
    if (endDate != null) data['endDate'] = endDate;
    if (symptoms != null) data['symptoms'] = symptoms;
    if (notes != null) data['notes'] = notes;
    await _entriesRef(coupleId).doc(entryId).update(data);
  }

  Future<void> deleteEntry(String coupleId, String entryId) async {
    await _entriesRef(coupleId).doc(entryId).delete();
  }

  // ---- Settings / predictions ----

  Stream<PeriodSettings> watchSettings(String coupleId) {
    return _settingsRef(coupleId).snapshots().map(
      (doc) => PeriodSettings.fromMap(doc.data() as Map<String, dynamic>?),
    );
  }

  Future<void> updateSettings({
    required String coupleId,
    required int avgCycleLength,
    required int avgPeriodLength,
  }) async {
    await _settingsRef(coupleId).set({
      'avgCycleLength': avgCycleLength,
      'avgPeriodLength': avgPeriodLength,
    }, SetOptions(merge: true));
  }

  /// Simple client-side prediction from the most recent logged entries.
  /// Not a medical-grade calculation — just an average-based estimate,
  /// consistent with the "quiet little home tool" scope of the app.
  DateTime? predictNextPeriod(
    List<PeriodEntry> recentEntries,
    int avgCycleLength,
  ) {
    if (recentEntries.isEmpty) return null;
    final lastStart = DateTime.parse(recentEntries.first.startDate);
    return lastStart.add(Duration(days: avgCycleLength));
  }
}
