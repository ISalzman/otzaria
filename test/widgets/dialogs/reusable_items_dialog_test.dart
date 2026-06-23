import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/widgets/dialogs/reusable_items_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // AppCustomContentDialog משתמש ב-MediaQuery.of(context).size כדי לחשב את הרוחב.
  // בטסטים `setSurfaceSize` לא תמיד מתפשט ל-MediaQuery של דיאלוגים, לכן עוטפים
  // ידנית ב-MediaQuery עם הגודל הרצוי. הקונטיינר הפנימי של הדיאלוג הוא היחיד
  // עם padding מפורש של 16 (Dialog/Material עוטפים אותו ב-Containers נוספים
  // ללא ה-padding הזה).
  Container findInnerContainer() {
    return find
        .descendant(
          of: find.byType(AppCustomContentDialog),
          matching: find.byType(Container),
        )
        .evaluate()
        .map((e) => e.widget as Container)
        .singleWhere((c) => c.padding == const EdgeInsets.all(16));
  }

  Future<void> pumpDialog(
    WidgetTester tester,
    Size mediaSize, {
    String title = 'כותרת',
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: mediaSize),
        child: Material(
          child: AppCustomContentDialog(
            title: title,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('AppCustomContentDialog — רוחב רספונסיבי', () {
    testWidgets('מסך רחב: הדיאלוג מבקש רוחב של 50% מהמסך', (tester) async {
      await pumpDialog(tester, const Size(1200, 800));

      final requested = findInnerContainer().constraints!.maxWidth;
      expect(requested, closeTo(600, 0.5),
          reason: '1200 * 0.5 = 600 — שמירה על ההתנהגות במסך רחב');
    });

    testWidgets('מסך צר: הדיאלוג מבקש רוחב של 95% מהמסך', (tester) async {
      await pumpDialog(tester, const Size(400, 800));

      final requested = findInnerContainer().constraints!.maxWidth;
      expect(requested, closeTo(380, 0.5),
          reason:
              '400 * 0.95 = 380 — בלי תיקון היה 200 (50%) והטקסט היה קורס לתו-לשורה');
    });

    testWidgets('הכותרת מוצגת', (tester) async {
      await pumpDialog(tester, const Size(800, 600));
      expect(find.text('כותרת'), findsOneWidget);
    });
  });

  group('AppCustomContentDialog — כותרת רספונסיבית', () {
    testWidgets('הכותרת עטופה ב-FittedBox עם BoxFit.scaleDown', (tester) async {
      await pumpDialog(tester, const Size(800, 600));

      final fittedBoxes = tester
          .widgetList<FittedBox>(find.byType(FittedBox))
          .where((fb) => fb.fit == BoxFit.scaleDown)
          .toList();
      expect(fittedBoxes, isNotEmpty,
          reason: 'חייב להיות לפחות FittedBox אחד עם scaleDown לכותרת');
    });

    testWidgets('ה-Text של הכותרת מוגבל לשורה אחת', (tester) async {
      await pumpDialog(tester, const Size(800, 600));

      final titleText = tester.widget<Text>(find.text('כותרת'));
      expect(titleText.maxLines, 1);
    });

    testWidgets('כותרת ארוכה לא גולשת מהשורה גם במסך צר', (tester) async {
      const longTitle = 'כותרת ארוכה מאוד שעשויה לגלוש בתצוגה רגילה';
      await pumpDialog(tester, const Size(350, 700), title: longTitle);

      // הטקסט חייב להופיע (FittedBox מקטין ולא חוסם)
      expect(find.text(longTitle), findsOneWidget);

      // FittedBox עם scaleDown קיים
      final fittedBox = tester
          .widgetList<FittedBox>(find.byType(FittedBox))
          .firstWhere((fb) => fb.fit == BoxFit.scaleDown);
      expect(fittedBox.fit, BoxFit.scaleDown);
    });
  });
}
