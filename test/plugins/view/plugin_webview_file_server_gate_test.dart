import 'dart:io';

import 'package:test/test.dart';

/// בדיקה סטטית: **כל** שער WebView של תוסף מאשר גם את נתיב ההעלאה (`/w/`).
///
/// השערים חוסמים כל בקשה לשרת הקבצים הפנימי שאינה מזוהה כשל התוסף הפונה,
/// ו-`isUriForPlugin` מכיר רק נתיבי קבצים (`/f/...`) — כלומר שער ששוכח את
/// נתיב ההעלאה מפיל **כל שמירה בינארית** של התוסף. ומה שהמשתמש רואה אינו
/// 403: לתשובה הסינתטית שהשער מייצר אין כותרות CORS, ולכן ה-fetch נזרק
/// כ-TypeError אטום ("Failed to fetch"), בלי שום עקבה שמצביעה על השער.
///
/// זו הסיבה שהבדיקה סטטית ולא התנהגותית: השערים הם callbacks בתוך
/// [StatefulWidget] שדורש WebView חי, אין דרך להריץ אותם בטסט — ובדיוק לכן
/// התיקון נעשה פעם אחת בשער של הכרטיסיה ונשכח בשער של מופע הרקע.
/// ההחלטה עצמה נבדקת ב-test/plugins/services/plugin_file_server_test.dart.
void main() {
  const gates = {
    'lib/plugins/view/plugin_tab_page.dart': 'שער הכרטיסיה',
    'lib/plugins/view/plugin_background_host.dart': 'שער מופע הרקע',
  };

  gates.forEach((path, name) {
    group(name, () {
      final source = File(path).readAsStringSync();

      test('הקובץ נקרא — הנתיב תקין', () {
        expect(source, contains('PluginFileServer'));
      });

      test('נתיב ההעלאה (/w/) מאושר לתוסף עצמו', () {
        expect(
          source,
          contains('isUploadUriForPlugin'),
          reason:
              'בלי ההיתר הזה ה-PUT של fs.beginBinaryWrite נחסם בשער, וכל '
              'שמירה בינארית של התוסף נופלת ב-"Failed to fetch"',
        );
      });

      test('חסימה של בקשה לשרת הקבצים נרשמת ללוג הריצה', () {
        expect(
          source,
          contains('_logFileServerDenial'),
          reason:
              'החסימה מגיעה ל-JS כ-TypeError בלי סטטוס; בלי הרישום אין שום '
              'דרך לדעת מה נחסם',
        );
      });
    });
  });
}
