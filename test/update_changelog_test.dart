import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/update/my_update_widget.dart';

void main() {
  group('changelogBetweenVersionsForUpdateDialog', () {
    test('returns only versions between current and latest, including headings',
        () {
      const changelog = '''
* **0.9.92**
  - שינוי חדש

* **0.9.91**
  - תיקון ביניים

* **0.9.90**
  - שינוי ישן
''';

      final result = changelogBetweenVersionsForUpdateDialog(
        changelog: changelog,
        currentVersion: '0.9.90+9900',
        latestVersion: '0.9.92',
      );

      expect(result, contains('* **0.9.92**'));
      expect(result, contains('  - שינוי חדש'));
      expect(result, contains('* **0.9.91**'));
      expect(result, contains('  - תיקון ביניים'));
      expect(result, isNot(contains('* **0.9.90**')));
      expect(result, isNot(contains('  - שינוי ישן')));
    });

    test('skips unheaded top changes because they are not released yet', () {
      const changelog = '''
  - שינוי ללא כותרת

* **0.9.91**
  - שינוי זמין

* **0.9.90**
  - שינוי ישן
''';

      final result = changelogBetweenVersionsForUpdateDialog(
        changelog: changelog,
        currentVersion: '0.9.90',
        latestVersion: '0.9.91-dev.1',
      );

      expect(result, contains('* **0.9.91**'));
      expect(result, contains('  - שינוי זמין'));
      expect(result, isNot(contains('  - שינוי ללא כותרת')));
      expect(result, isNot(contains('  - שינוי ישן')));
    });
  });
}
