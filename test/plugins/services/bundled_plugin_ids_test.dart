import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/bundled_plugin_ids.dart';

void main() {
  group('bundledPluginIdsForPlatform — סינון לפי סיומת @פלטפורמות', () {
    const plugins = {
      'store1': 'com.everywhere.plugin',
      'store2': 'com.desktop.plugin@windows,linux,macos',
      'store3': 'com.mobile.plugin@android,ios',
    };

    test('רשומה בלי @ נכללת בכל פלטפורמה', () {
      for (final platform in ['windows', 'linux', 'macos', 'android', 'ios']) {
        expect(
          bundledPluginIdsForPlatform(platform, plugins),
          contains('com.everywhere.plugin'),
        );
      }
    });

    test('רשומה עם @ נכללת רק בפלטפורמות שברשימתה, בלי הסיומת במזהה', () {
      expect(bundledPluginIdsForPlatform('windows', plugins), {
        'com.everywhere.plugin',
        'com.desktop.plugin',
      });
      expect(bundledPluginIdsForPlatform('android', plugins), {
        'com.everywhere.plugin',
        'com.mobile.plugin',
      });
    });

    test('הרשימה האמיתית תקינה: מזהי מניפסט בלי תווים אסורים', () {
      // שם הקובץ בארכיון נגזר מהמזהה — אותו אימות שסקריפטי ההורדה אוכפים.
      final idPattern = RegExp(r'^[A-Za-z0-9._-]+$');
      for (final platform in ['windows', 'linux', 'macos', 'android', 'ios']) {
        for (final id in bundledPluginIdsForPlatform(platform)) {
          expect(id, matches(idPattern));
        }
      }
    });
  });
}
