import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_note.dart';

class ProfileNotesService {
  CollectionReference<Map<String, dynamic>> _notesRef(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profileNotes');

  Stream<List<UserNote>> watchNotes(String uid, NoteCategory category) {
    return _notesRef(uid)
        .where(
          'category',
          isEqualTo: category == NoteCategory.favorite ? 'favorite' : 'note',
        )
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => UserNote.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> saveNote({required String uid, required UserNote note}) async {
    await _notesRef(uid).doc(note.id).set(note.toMap());
  }

  Future<void> deleteNote({required String uid, required String noteId}) async {
    await _notesRef(uid).doc(noteId).delete();
  }
}
