import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';

class NotesService {
  CollectionReference _notesRef(String coupleId) => FirebaseFirestore.instance
      .collection('couples')
      .doc(coupleId)
      .collection('notes');

  Stream<List<Note>> watchSharedNotes(String coupleId) {
    return _notesRef(coupleId)
        .where('visibility', isEqualTo: 'shared')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Note.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Stream<List<Note>> watchPrivateNotes(String coupleId, String uid) {
    return _notesRef(coupleId)
        .where('visibility', isEqualTo: 'private:$uid')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Note.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Future<String> createNote({
    required String coupleId,
    required String title,
    required String contentJson,
    required String visibility,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    final docRef = await _notesRef(coupleId).add({
      'title': title,
      'contentJson': contentJson,
      'visibility': visibility,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    return docRef.id;
  }

  Future<void> updateNote({
    required String coupleId,
    required String noteId,
    required String title,
    required String contentJson,
    required String visibility,
  }) async {
    await _notesRef(coupleId).doc(noteId).update({
      'title': title,
      'contentJson': contentJson,
      'visibility': visibility,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteNote(String coupleId, String noteId) async {
    await _notesRef(coupleId).doc(noteId).delete();
  }
}
