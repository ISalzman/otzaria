import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/docx_cache.dart';

/// בדיקות ללוגיקת הזרקת-הכותרת של מטמון ה-docx. המטמון מפתוח לפי הקובץ
/// (לא לפי שם הספר), כך ששינוי-שם אינו פוסל את המטמון אך הכותרת מתעדכנת.
void main() {
  group('withFreshDocxTitle', () {
    test('מחליף את שורת הכותרת בשם הנוכחי, שומר את שאר התוכן', () {
      const cached = '<h1>שם ישן</h1>\n<p>תוכן הספר</p>\nעוד שורה';
      final result = withFreshDocxTitle(cached, 'שם חדש');
      expect(result, '<h1>שם חדש</h1>\n<p>תוכן הספר</p>\nעוד שורה');
    });

    test('טקסט עם h1 בלבד (בלי שורות נוספות) מתעדכן', () {
      const cached = '<h1>ישן</h1>';
      expect(withFreshDocxTitle(cached, 'חדש'), '<h1>חדש</h1>');
    });

    test('טקסט שאינו פותח ב-h1 מוחזר כפי שהוא', () {
      const cached = '<p>בלי כותרת</p>\nשורה';
      expect(withFreshDocxTitle(cached, 'שם'), cached);
    });

    test('כותרת זהה משאירה את התוכן ללא שינוי מהותי', () {
      const cached = '<h1>אותו שם</h1>\nתוכן';
      expect(withFreshDocxTitle(cached, 'אותו שם'), cached);
    });
  });
}
