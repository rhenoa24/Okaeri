import 'package:flutter_test/flutter_test.dart';
import 'package:okaeri/models/calendar_note.dart';

void main() {
  test('CalendarNote preserves contentJson when parsed and serialized', () {
    final note = CalendarNote.fromMap('note-1', {
      'date': '2026-07-08',
      'title': 'Anniversary',
      'contentJson': '[{"insert":"Hello\\n"}]',
      'isRepeating': true,
      'isImportant': true,
      'createdBy': 'user-1',
      'createdAt': null,
    });

    expect(note.contentJson, '[{"insert":"Hello\\n"}]');
    expect(note.toMap()['contentJson'], '[{"insert":"Hello\\n"}]');
  });
}
