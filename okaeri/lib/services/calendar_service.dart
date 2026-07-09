import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_note.dart';
import '../models/plan.dart';

String todayDateString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class CalendarData {
  const CalendarData({required this.notes, required this.plans});

  final List<CalendarNote> notes;
  final List<Plan> plans;
}

class CalendarService {
  CollectionReference _notesRef(String coupleId) => FirebaseFirestore.instance
      .collection('couples')
      .doc(coupleId)
      .collection('calendarNotes');

  CollectionReference _plansRef(String coupleId) => FirebaseFirestore.instance
      .collection('couples')
      .doc(coupleId)
      .collection('plans');

  // Fetch ALL notes for this couple. At a 2-person scale this collection
  // stays tiny, so filtering by date (including yearly repeats) happens
  // client-side in the screens rather than via complex Firestore queries.
  Stream<List<CalendarNote>> watchAllNotes(String coupleId) {
    return _notesRef(coupleId).snapshots().map(
      (snap) => snap.docs
          .map(
            (d) => CalendarNote.fromMap(d.id, d.data() as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Stream<List<Plan>> watchPlansForDate(String coupleId, String date) {
    return _plansRef(coupleId)
        .where('date', isEqualTo: date)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Plan.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Stream<CalendarData> watchCalendarData(String coupleId) {
    return Stream.multi((controller) {
      List<CalendarNote> notes = [];
      List<Plan> plans = [];
      bool hasNotes = false;
      bool hasPlans = false;

      void emitIfReady() {
        if (hasNotes && hasPlans) {
          controller.add(CalendarData(notes: notes, plans: plans));
        }
      }

      late final StreamSubscription<List<CalendarNote>> notesSub;
      late final StreamSubscription<List<Plan>> plansSub;

      notesSub = watchAllNotes(coupleId).listen((value) {
        notes = value;
        hasNotes = true;
        emitIfReady();
      }, onError: controller.addError);

      plansSub = watchPlans(coupleId, limit: 1000).listen((value) {
        plans = value;
        hasPlans = true;
        emitIfReady();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await notesSub.cancel();
        await plansSub.cancel();
      };
    });
  }

  // All plans, ordered by date. Each doc is one titled plan with its own
  // embedded timetable, so this is already "grouped" — no client-side
  // grouping-by-timestamp needed like the old Plan model.
  Stream<List<Plan>> watchPlans(String coupleId, {int limit = 50}) {
    return _plansRef(coupleId)
        .orderBy('date')
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Plan.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  // Plans from today onward, soonest first. Used for the "Upcoming Plans"
  // preview on Home and its full list screen.
  Stream<List<Plan>> watchUpcomingPlans(String coupleId, {int limit = 5}) {
    return _plansRef(coupleId)
        .where('date', isGreaterThanOrEqualTo: todayDateString())
        .orderBy('date')
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Plan.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Future<void> createNote({
    required String coupleId,
    required String date,
    required String title,
    required String contentJson,
    required bool isRepeating,
    required bool isImportant,
    required String createdBy,
  }) async {
    await _notesRef(coupleId).add({
      'date': date,
      'title': title,
      'contentJson': contentJson,
      'isRepeating': isRepeating,
      'isImportant': isImportant,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateNote({
    required String coupleId,
    required String noteId,
    required String date,
    required String title,
    required String contentJson,
    required bool isRepeating,
    required bool isImportant,
  }) async {
    await _notesRef(coupleId).doc(noteId).update({
      'date': date,
      'title': title,
      'contentJson': contentJson,
      'isRepeating': isRepeating,
      'isImportant': isImportant,
    });
  }

  Future<void> deleteNote(String coupleId, String noteId) async {
    await _notesRef(coupleId).doc(noteId).delete();
  }

  Future<void> createPlan({
    required String coupleId,
    required String date,
    required String title,
    required List<TimetableEntry> timetable,
    required String createdBy,
  }) async {
    await _plansRef(coupleId).add({
      'date': date,
      'title': title,
      'timetable': timetable.map((e) => e.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updatePlan({
    required String coupleId,
    required String planId,
    required String date,
    required String title,
    required List<TimetableEntry> timetable,
  }) async {
    await _plansRef(coupleId).doc(planId).update({
      'date': date,
      'title': title,
      'timetable': timetable.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> deletePlan(String coupleId, String planId) async {
    await _plansRef(coupleId).doc(planId).delete();
  }
}
