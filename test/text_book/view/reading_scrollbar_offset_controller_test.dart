import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// גרירת פס הגלילה גוללת *בתוך* קטע גבוה מהמסך רק כשהסרגל מקבל
/// `offsetController`; בלעדיו היא מסוגלת לקפוץ בין אינדקסים בלבד, ובספר
/// שכולו קטע אחד אין לאן לקפוץ והגרירה אינה מזיזה דבר (issue #1169).
///
/// הרשימות בשני מסכי הקריאה כבר מחוברות ל-`ScrollOffsetController`, ולכן
/// המבחן כאן הוא שגם הסרגל שעוטף אותן מקבל אותו.
void main() {
  const surfaces = {
    'lib/text_book/view/combined_view/combined_book_screen.dart': 2,
    'lib/text_book/view/page_shape/simple_text_viewer.dart': 1,
  };

  group('פס הגלילה במסכי הקריאה מקבל offsetController', () {
    surfaces.forEach((path, expectedScrollbars) {
      test(path.split('/').last, () {
        final source = File(path).readAsStringSync();
        final scrollbars = 'ScrollablePositionedListScrollbar('
            .allMatches(source)
            .length;

        expect(
          scrollbars,
          expectedScrollbars,
          reason: 'השתנה מספר הסרגלים בקובץ — יש לעדכן את הבדיקה',
        );
        expect(
          'offsetController:'.allMatches(source).length,
          greaterThanOrEqualTo(scrollbars),
          reason: 'כל סרגל במסך קריאה חייב לקבל offsetController',
        );
      });
    });
  });
}
