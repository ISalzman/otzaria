import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/services/personal_note_draft_service.dart';
import 'package:otzaria/personal_notes/widgets/note_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NoteTile פותח אוטומטית עריכה כשיש טיוטה להערה קיימת',
      (tester) async {
    final draftService = PersonalNoteDraftService();
    await draftService.saveDraft(
      bookId: 'ספר מבחן',
      noteId: 'note-1',
      draft: PersonalNoteDraft(
        content: 'טיוטה חדשה',
        contentPlain: 'טיוטה חדשה',
        contentFormat: PersonalNoteContentFormat.plain,
        updatedAt: DateTime(2026, 1, 5),
        noteId: 'note-1',
      ),
    );

    final note = PersonalNote(
      id: 'note-1',
      bookId: 'ספר מבחן',
      lineNumber: 4,
      displayTitle: 'שורה 4',
      lastKnownLineNumber: 4,
      status: PersonalNoteStatus.located,
      content: 'תוכן שמור',
      contentPlain: 'תוכן שמור',
      contentFormat: PersonalNoteContentFormat.plain,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteTile(
            note: note,
            defaultExpanded: false,
            bookId: 'ספר מבחן',
            linkableNotes: const [],
            onSave: (_) {},
            onDelete: () {},
            onLinkTap: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('שמור'), findsOneWidget);
    expect(find.text('ביטול'), findsOneWidget);
  });
}
