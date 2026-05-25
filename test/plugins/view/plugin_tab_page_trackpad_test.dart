// בדיקות יחידה לגלילת לוח מגע (trackpad) בתוספים.
//
// במקום לסרוק מחרוזות בקוד מקור, הטסטים בודקים את הפונקציה
// buildTrackpadScrollJs ישירות — מה שמבטיח שה-JavaScript שמוזרק
// לדפדפן תואם את תנועת האצבעות בפועל.
//
// ודא שהפונקציה buildTrackpadScrollJs מוגדרת ב-plugin_tab_page.dart
// כ-@visibleForTesting ומיוצאת ברמת הקובץ (לא כמתודה של קלאס).

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/view/plugin_tab_page.dart';

void main() {
  group('buildTrackpadScrollJs', () {
    test('גלילה למטה מייצרת dy חיובי ב-scrollBy', () {
      final js = buildTrackpadScrollJs(const Offset(0, 40));
      expect(js, contains('window.scrollBy('));
      // dy=40 → גלילה למטה (תוכן עולה, יותר תוכן מתחת)
      expect(js, contains(',40.00)'));
    });

    test('גלילה למעלה מייצרת dy שלילי ב-scrollBy', () {
      final js = buildTrackpadScrollJs(const Offset(0, -30));
      expect(js, contains(',-30.00)'));
    });

    test('גלילה אופקית ימינה מייצרת dx חיובי', () {
      final js = buildTrackpadScrollJs(const Offset(25, 0));
      expect(js, contains('(25.00,'));
    });

    test('אפס דלתא מייצר scrollBy(0.00,0.00)', () {
      final js = buildTrackpadScrollJs(Offset.zero);
      expect(js, 'window.scrollBy(0.00,0.00);');
    });

    test('ערכים עשרוניים מועברים ב-2 ספרות אחרי הנקודה', () {
      final js = buildTrackpadScrollJs(const Offset(10.5, -7.123));
      // 10.5 → 10.50 ; -7.123 מעוגל ל-2 ספרות → -7.12
      expect(js, 'window.scrollBy(10.50,-7.12);');
    });

    test('הפלט הוא JavaScript תקין (ניתן לפרסור כביטוי)', () {
      final js = buildTrackpadScrollJs(const Offset(15, 20));
      // הפלט חייב להתחיל ב-window.scrollBy ולהסתיים ב-;
      expect(js, startsWith('window.scrollBy('));
      expect(js, endsWith(';'));
      // ודא שאין NaN או Infinity שיפרו את ה-JS
      expect(js, isNot(contains('NaN')));
      expect(js, isNot(contains('Infinity')));
    });

    test('גלילה אלכסונית כוללת גם dx וגם dy', () {
      final js = buildTrackpadScrollJs(const Offset(10, 20));
      expect(js, 'window.scrollBy(10.00,20.00);');
    });
  });
}
