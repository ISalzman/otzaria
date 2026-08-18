import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/view/pdf_book_screen.dart';

void main() {
  // כפולה של שני עמודי 400x600 עם השדרה במרכז, בזום 1 ובלי הזזה.
  const spreadRect = Rect.fromLTWH(0, 0, 800, 600);
  final matrix = Matrix4.identity();

  group('מלבן הכפולה לדפדוף מול המלבן הנראה', () {
    test('כשהכפולה נכנסת בתצוגה שני המלבנים זהים', () {
      const viewportSize = Size(900, 700);

      expect(
        pdfSpreadVisibleViewportRect(matrix, spreadRect, viewportSize),
        pdfSpreadTurnViewportRect(matrix, spreadRect),
      );
    });

    test(
      'כשהתצוגה מצרה (חלונית ניווט) ציר הקיפול נשאר על השדרה — issue #868',
      () {
        // רוחב תצוגה 600 בלבד: הכפולה גולשת ב-200 פיקסלים.
        const viewportSize = Size(600, 700);
        final turnRect = pdfSpreadTurnViewportRect(matrix, spreadRect);
        final visibleRect = pdfSpreadVisibleViewportRect(
          matrix,
          spreadRect,
          viewportSize,
        )!;

        expect(turnRect.center.dx, closeTo(spreadRect.center.dx, 0.01));
        expect(turnRect.width / 2, closeTo(400, 0.01));

        // המלבן הנראה חתוך — אילו הוא היה מזין את הגאומטריה, ציר הקיפול
        // היה נוחת בתוך העמוד הימני במקום על השדרה.
        expect(visibleRect.width, closeTo(600, 0.01));
        expect(visibleRect.center.dx, isNot(closeTo(turnRect.center.dx, 1.0)));
      },
    );

    test('מלבן נראה ריק כשהכפולה מחוץ לתצוגה', () {
      final scrolled = Matrix4.identity()
        ..translateByDouble(-900.0, 0.0, 0.0, 1.0);

      expect(
        pdfSpreadVisibleViewportRect(
          scrolled,
          spreadRect,
          const Size(600, 700),
        ),
        isNull,
      );
      expect(
        pdfSpreadTurnViewportRect(scrolled, spreadRect).width,
        closeTo(800, 0.01),
      );
    });
  });
}
