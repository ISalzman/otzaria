import 'dart:io';

import 'package:test/test.dart';

/// ה-WebView אינו זמין בטסט, ולכן בודקים שכל אחד משני השערים משתמש בהחלטה
/// המאושרת לנתיב `/w/` של התוסף.
void main() {
  const gates = {
    'lib/plugins/view/plugin_tab_page.dart': 'שער הכרטיסיה',
    'lib/plugins/view/plugin_background_host.dart': 'שער מופע הרקע',
  };

  gates.forEach((path, name) {
    group(name, () {
      final source = File(path).readAsStringSync();

      test('שני השערים משתמשים בהחלטת נתיב ההעלאה', () {
        expect(
          RegExp(r'_isOwnFileServerRequest\(uri\)').allMatches(source),
          hasLength(2),
        );
        expect(source, contains('isUploadUriForPlugin'));
      });

      test('חסימות נרשמות לכל היותר פעם בדקה', () {
        expect(
          RegExp(r'_logFileServerDenial\(uri\)').allMatches(source),
          hasLength(2),
        );
        expect(source, contains('_fileServerDenialLogInterval'));
        expect(
          source,
          contains(
            'now.difference(lastLogAt) < _fileServerDenialLogInterval',
          ),
        );
      });
    });
  });
}
