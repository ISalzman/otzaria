import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/selection/selection_hit_test.dart';

void main() {
  // RichText רחב בשורה אחת: "AAAA BBBB" — "AAAA" בחצי השמאלי, "BBBB" בימני.
  Future<RenderParagraph> pumpRichText(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            // ללא רוחב קבוע — הפסקה מתכווצת לרוחב הטקסט, כך שהמרכז על הזכוכיות.
            child: Text(
              'AAAA BBBB',
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderParagraph>(find.byType(RichText));
  }

  testWidgets('edge.full: לחיצה במרכז הטקסט נחשבת על הבחירה', (tester) async {
    final paragraph = await pumpRichText(tester);

    final result = clickIsOnRenderedSelection(
      root: paragraph,
      globalPosition: tester.getCenter(find.byType(RichText)),
      selectedSegment: 'AAAA BBBB',
      edge: SelectionSegmentEdge.full,
    );

    expect(result, isTrue);
  });

  testWidgets('edge.substring: לחיצה על הקטע המסומן בלבד', (tester) async {
    final paragraph = await pumpRichText(tester);
    final topLeft = tester.getTopLeft(find.byType(RichText));
    final size = tester.getSize(find.byType(RichText));
    final centerY = topLeft.dy + size.height / 2;

    // "AAAA" נמצא ברבע השמאלי — לחיצה שם על הבחירה.
    final onSelection = clickIsOnRenderedSelection(
      root: paragraph,
      globalPosition: Offset(topLeft.dx + size.width * 0.1, centerY),
      selectedSegment: 'AAAA',
      edge: SelectionSegmentEdge.substring,
    );
    expect(onSelection, isTrue,
        reason: 'לחיצה על "AAAA" המסומן צריכה להיחשב על הבחירה');

    // "BBBB" ברבע הימני — לחיצה שם מחוץ לבחירה ("AAAA" בלבד מסומן).
    final offSelection = clickIsOnRenderedSelection(
      root: paragraph,
      globalPosition: Offset(topLeft.dx + size.width * 0.9, centerY),
      selectedSegment: 'AAAA',
      edge: SelectionSegmentEdge.substring,
    );
    expect(offSelection, isFalse,
        reason: 'לחיצה על "BBBB" הלא-מסומן צריכה להיחשב מחוץ לבחירה');
  });

  testWidgets('לחיצה מחוץ לכל פסקה מחזירה null (לא הוכרע)', (tester) async {
    final paragraph = await pumpRichText(tester);

    final result = clickIsOnRenderedSelection(
      root: paragraph,
      globalPosition: const Offset(5, 5), // הפינה — מחוץ לפסקה הממורכזת
      selectedSegment: 'AAAA BBBB',
      edge: SelectionSegmentEdge.full,
    );

    expect(result, isNull);
  });

  testWidgets('edge.substring: קטע שמופיע פעמיים מחזיר null (אי-בהירות)',
      (tester) async {
    // "BB" מופיע גם ב-"ABBA" וגם ב-"BB" — לא ניתן לדעת על איזה מופע מדובר,
    // ולכן הבדיקה נסוגה לסלחני (null) במקום לבדוק מול המופע השגוי.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'ABBA xx BB',
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
    final paragraph =
        tester.renderObject<RenderParagraph>(find.byType(RichText));

    final result = clickIsOnRenderedSelection(
      root: paragraph,
      globalPosition: tester.getCenter(find.byType(RichText)),
      selectedSegment: 'BB',
      edge: SelectionSegmentEdge.substring,
    );

    expect(result, isNull,
        reason: 'מופע כפול ללא רמז — לא ניתן להכריע, חוזרים לסלחני');
  });

  testWidgets('edge.substring: רמז מיקום בוחר את המופע הנכון בטקסט חוזר',
      (tester) async {
    // "BB BB" — שני מופעים. הרמז מצביע על המופע השני (אינדקס 3), והלחיצה על
    // המופע השני (ימני) צריכה להיחשב על הבחירה; על הראשון (שמאלי) — מחוצה לה.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'BB BB',
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
    final paragraph =
        tester.renderObject<RenderParagraph>(find.byType(RichText));
    final topLeft = tester.getTopLeft(find.byType(RichText));
    final size = tester.getSize(find.byType(RichText));
    final centerY = topLeft.dy + size.height / 2;

    // לחיצה על המופע השני (ימני) — תואם לרמז 3 → על הבחירה.
    final onSecond = clickIsOnRenderedSelection(
      root: paragraph,
      globalPosition: Offset(topLeft.dx + size.width * 0.9, centerY),
      selectedSegment: 'BB',
      edge: SelectionSegmentEdge.substring,
      segmentStartHint: 3,
    );
    expect(onSecond, isTrue,
        reason: 'הרמז מצביע על המופע השני — לחיצה עליו על הבחירה');

    // לחיצה על המופע הראשון (שמאלי) — מחוץ למופע הנבחר (השני) → מבטל.
    final onFirst = clickIsOnRenderedSelection(
      root: paragraph,
      globalPosition: Offset(topLeft.dx + size.width * 0.1, centerY),
      selectedSegment: 'BB',
      edge: SelectionSegmentEdge.substring,
      segmentStartHint: 3,
    );
    expect(onFirst, isFalse,
        reason: 'לחיצה על המופע הלא-נבחר (הראשון) צריכה להיחשב מחוץ לבחירה');
  });

  testWidgets('edge.substring: קטע שלא קיים בטקסט מחזיר null', (tester) async {
    final paragraph = await pumpRichText(tester);

    final result = clickIsOnRenderedSelection(
      root: paragraph,
      globalPosition: tester.getCenter(find.byType(RichText)),
      selectedSegment: 'ZZZZ',
      edge: SelectionSegmentEdge.substring,
    );

    expect(result, isNull,
        reason: 'כשהקטע לא נמצא בפסקה — לא ניתן להכריע, והמתקשר יחזור לסלחני');
  });
}
