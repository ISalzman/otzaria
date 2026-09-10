import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/personal_notes/models/personal_note.dart';
import 'package:otzaria/personal_notes/widgets/personal_note_content_view.dart';
import 'package:otzaria/widgets/misc/app_selection_area.dart';

/// issue #1271 — בתיבת הריחוף של הערה (עטופה ב-AppSelectionArea) לחיצה ימנית
/// פתחה גם את תפריט ההעתקה של אוצריא וגם את תפריט Flutter של עורך ההערה.
void main() {
  PersonalNote note() => PersonalNote(
    id: 'pn_1',
    bookId: 'Test',
    lineNumber: 1,
    displayTitle: 'כותרת',
    lastKnownLineNumber: null,
    status: PersonalNoteStatus.located,
    content: jsonEncode([
      {'insert': 'תוכן ההערה לבדיקה'},
      {'insert': '\n'},
    ]),
    contentPlain: 'תוכן ההערה לבדיקה',
    contentFormat: PersonalNoteContentFormat.quillDelta,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
  );

  Future<void> rightClickText(WidgetTester tester) async {
    await tester.tapAt(
      tester.getCenter(find.text('תוכן ההערה לבדיקה', findRichText: true)),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('בתוך AppSelectionArea נפתח רק תפריט ההעתקה של אוצריא', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSelectionArea(child: PersonalNoteContentView(note: note())),
        ),
      ),
    );

    await rightClickText(tester);
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('העתק'), findsOneWidget, reason: 'תפריט אוצריא');
    expect(
      find.byType(AdaptiveTextSelectionToolbar),
      findsNothing,
      reason: 'תפריט Flutter של העורך אסור שיופיע לצד תפריט אוצריא (issue #1271)',
    );
  });

  testWidgets('בלי AppSelectionArea תפריט ההעתקה של העורך נשאר זמין', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PersonalNoteContentView(note: note())),
      ),
    );

    await rightClickText(tester);
    debugDefaultTargetPlatformOverride = null;

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
  });
}
