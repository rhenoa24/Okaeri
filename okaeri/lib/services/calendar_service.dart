import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_note.dart';
import '../models/schedule_item.dart';

String todayDateString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class CalendarData {
  const CalendarData({required this.notes, required this.plans});

  final List<CalendarNote> notes;
  final List<ScheduleItem> plans;
}

class CalendarService {
  CollectionReference _notesRef(String coupleId) => FirebaseFirestore.instance
      .collection('couples')
      .doc(coupleId)
      .collection('calendarNotes');

  CollectionReference _scheduleRef(String coupleId) => FirebaseFirestore
      .instance
      .collection('couples')
      .doc(coupleId)
      .collection('scheduleItems');

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

  Stream<List<ScheduleItem>> watchScheduleForDate(
    String coupleId,
    String date,
  ) {
    return _scheduleRef(coupleId)
        .where('date', isEqualTo: date)
        .orderBy('time')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => ScheduleItem.fromMap(
                  d.id,
                  d.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  Stream<CalendarData> watchCalendarData(String coupleId) {
    return Stream.multi((controller) {
      List<CalendarNote> notes = [];
      List<ScheduleItem> plans = [];
      bool hasNotes = false;
      bool hasPlans = false;

      void emitIfReady() {
        if (hasNotes && hasPlans) {
          controller.add(CalendarData(notes: notes, plans: plans));
        }
      }

      late final StreamSubscription<List<CalendarNote>> notesSub;
      late final StreamSubscription<List<ScheduleItem>> plansSub;

      notesSub = watchAllNotes(coupleId).listen((value) {
        notes = value;
        hasNotes = true;
        emitIfReady();
      }, onError: controller.addError);

      plansSub = watchSchedule(coupleId, limit: 1000).listen((value) {
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

  Stream<List<ScheduleItem>> watchSchedule(String coupleId, {int limit = 50}) {
    return _scheduleRef(coupleId)
        .orderBy('date')
        .orderBy('time')
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => ScheduleItem.fromMap(
                  d.id,
                  d.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  // Schedule items from today onward, across all days, soonest first.
  // Used for the "Upcoming Plans" preview on Home and its full list screen.
  Stream<List<ScheduleItem>> watchUpcomingSchedule(
    String coupleId, {
    int limit = 5,
  }) {
    return _scheduleRef(coupleId)
        .where('date', isGreaterThanOrEqualTo: todayDateString())
        .orderBy('date')
        .orderBy('time')
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => ScheduleItem.fromMap(
                  d.id,
                  d.data() as Map<String, dynamic>,
                ),
              )
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

  Future<void> createScheduleItem({
    required String coupleId,
    required String date,
    required String time,
    required String text,
    required String createdBy,
  }) async {
    await _scheduleRef(
      coupleId,
    ).add({'date': date, 'time': time, 'text': text, 'createdBy': createdBy});
  }

  Future<void> updateScheduleItem({
    required String coupleId,
    required String itemId,
    required String time,
    required String text,
  }) async {
    await _scheduleRef(
      coupleId,
    ).doc(itemId).update({'time': time, 'text': text});
  }

  Future<void> deleteScheduleItem(String coupleId, String itemId) async {
    await _scheduleRef(coupleId).doc(itemId).delete();
  }
}
