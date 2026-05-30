import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_content_view.dart';

void main() {
  testWidgets('renders link chips for delta links', (tester) async {
    final delta = jsonEncode([
      {
        'insert': 'קישור',
        'attributes': {
          'link': 'otzaria://book?bookId=Test&line=1',
        },
      },
      {'insert': '\n'},
    ]);

    final note = PersonalNote(
      id: 'pn_1',
      bookId: 'Test',
      lineNumber: 1,
      displayTitle: 'כותרת',
      lastKnownLineNumber: null,
      status: PersonalNoteStatus.located,
      content: delta,
      contentPlain: 'קישור',
      contentFormat: PersonalNoteContentFormat.quillDelta,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonalNoteContentView(note: note),
        ),
      ),
    );

    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.text('קישור'), findsOneWidget);
  });

  testWidgets('בונה מחדש את הקישורים כשה-note מתחלף', (tester) async {
    PersonalNote noteWithLink(String label, String url) => PersonalNote(
          id: 'pn_1',
          bookId: 'Test',
          lineNumber: 1,
          displayTitle: 'כותרת',
          lastKnownLineNumber: null,
          status: PersonalNoteStatus.located,
          content: jsonEncode([
            {
              'insert': label,
              'attributes': {'link': url},
            },
            {'insert': '\n'},
          ]),
          contentPlain: label,
          contentFormat: PersonalNoteContentFormat.quillDelta,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 2),
        );

    late StateSetter setState;
    var note = noteWithLink('קישור ראשון', 'otzaria://book?bookId=A&line=1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setter) {
              setState = setter;
              // אותו מיקום ב-widget tree (ללא key ייחודי) → החלפת ה-note
              // עוברת דרך didUpdateWidget ולא דרך initState של מופע חדש.
              return PersonalNoteContentView(note: note);
            },
          ),
        ),
      ),
    );

    expect(find.text('קישור ראשון'), findsOneWidget);

    setState(() {
      note = noteWithLink('קישור שני', 'otzaria://book?bookId=B&line=2');
    });
    await tester.pump();

    expect(find.text('קישור ראשון'), findsNothing);
    expect(find.text('קישור שני'), findsOneWidget);
  });
}
