import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/ui_snack.dart';

/// בדיקות ללחיצוּת של הודעות [UiSnack] — פרמטר onTap.
void main() {
  tearDown(UiSnack.hide);

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
  }

  testWidgets('לחיצה על הודעה עם onTap מפעילה את הפעולה וסוגרת אותה', (
    tester,
  ) async {
    await pumpHost(tester);
    var tapped = 0;
    UiSnack.show('הודעה לחיצה', onTap: () => tapped++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('הודעה לחיצה'), findsOneWidget);

    await tester.tap(find.text('הודעה לחיצה'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(find.text('הודעה לחיצה'), findsNothing);
  });

  testWidgets('onTap נתמך גם ב-showError, showSuccess ו-showWarning', (
    tester,
  ) async {
    await pumpHost(tester);
    final tappedLabels = <String>[];
    for (final (label, show)
        in <(String, void Function(String, {VoidCallback? onTap}))>[
          ('שגיאה', UiSnack.showError),
          ('הצלחה', UiSnack.showSuccess),
          ('אזהרה', UiSnack.showWarning),
        ]) {
      show(label, onTap: () => tappedLabels.add(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(tappedLabels, ['שגיאה', 'הצלחה', 'אזהרה']);
  });

  testWidgets('הודעה בלי onTap אינה מגיבה ללחיצה', (tester) async {
    await pumpHost(tester);
    UiSnack.show('הודעה רגילה');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('הודעה רגילה'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('הודעה רגילה'), findsOneWidget);

    // סגירה בתוך גוף הבדיקה — אחרת טיימר ההסתרה האוטומטית נשאר תלוי.
    UiSnack.hide();
    await tester.pump();
  });
}
