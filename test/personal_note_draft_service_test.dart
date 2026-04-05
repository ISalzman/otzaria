import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/services/personal_note_draft_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadLatestNewNoteDraft מחזיר את הטיוטה החדשה האחרונה של הספר', () async {
    final service = PersonalNoteDraftService();

    await service.saveDraft(
      bookId: 'ספר א',
      lineNumber: 3,
      draft: PersonalNoteDraft(
        content: 'ישן',
        contentPlain: 'ישן',
        contentFormat: PersonalNoteContentFormat.plain,
        updatedAt: DateTime(2026, 1, 1),
        lineNumber: 3,
      ),
    );
    await service.saveDraft(
      bookId: 'ספר א',
      lineNumber: 7,
      draft: PersonalNoteDraft(
        content: 'חדש',
        contentPlain: 'חדש',
        contentFormat: PersonalNoteContentFormat.plain,
        updatedAt: DateTime(2026, 1, 2),
        lineNumber: 7,
        referenceText: 'כותרת',
      ),
    );
    await service.saveDraft(
      bookId: 'ספר א',
      noteId: 'note-1',
      draft: PersonalNoteDraft(
        content: 'טיוטת עריכה',
        contentPlain: 'טיוטת עריכה',
        contentFormat: PersonalNoteContentFormat.plain,
        updatedAt: DateTime(2026, 1, 3),
        noteId: 'note-1',
      ),
    );

    final latest = await service.loadLatestNewNoteDraft(bookId: 'ספר א');

    expect(latest, isNotNull);
    expect(latest!.lineNumber, 7);
    expect(latest.contentPlain, 'חדש');
    expect(latest.referenceText, 'כותרת');
  });

  test('אפשר לשמור ולטעון טיוטה של הערה קיימת לפי noteId', () async {
    final service = PersonalNoteDraftService();

    await service.saveDraft(
      bookId: 'ספר ב',
      noteId: 'note-42',
      draft: PersonalNoteDraft(
        content: '{"ops":[{"insert":"שלום"}]}',
        contentPlain: 'שלום',
        contentFormat: PersonalNoteContentFormat.quillDelta,
        updatedAt: DateTime(2026, 1, 4),
        noteId: 'note-42',
      ),
    );

    final loaded = await service.loadDraft(
      bookId: 'ספר ב',
      noteId: 'note-42',
    );

    expect(loaded, isNotNull);
    expect(loaded!.noteId, 'note-42');
    expect(loaded.contentPlain, 'שלום');
    expect(loaded.contentFormat, PersonalNoteContentFormat.quillDelta);
  });
}
