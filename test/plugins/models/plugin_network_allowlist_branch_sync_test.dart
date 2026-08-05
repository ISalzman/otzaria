import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_network_allowlist.dart';

/// מקור האמת לגישת רשת של תוספים הוא `plugin_network_allowlist.txt` שבשורש
/// הריפו — האפליקציה מושכת אותו מענף dev בזמן ריצה, והרשימה המקומפלת היא
/// גיבוי לא-מקוון בלבד. כתובת שקיימת רק ברשימה המקומפלת תיחסם אצל משתמשים
/// (הקובץ גובר עליה כשהוא נטען), ולכן כל ערך מקומפל חייב להופיע גם בקובץ.
///
/// הבדיקה קוראת את הקובץ המקומי ולא מושכת מ-GitHub: כך היא בודקת את התוכן
/// של ה-PR עצמו ולא את מה שכבר ממוזג ב-dev, ואינה תלויה ברשת.
void main() {
  test(
    'כל כתובת ברשימה המקומפלת מופיעה גם בקובץ plugin_network_allowlist.txt',
    () {
      final file = File('plugin_network_allowlist.txt');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'הקובץ ${file.path} חייב להתקיים בשורש הריפו — הוא מקור האמת '
            'שהאפליקציה מושכת מענף dev',
      );

      final fileAllowlist = parsePluginNetworkAllowlistText(
        file.readAsStringSync(),
      );
      final missing = pluginNetworkAllowlist
          .where((entry) => !fileAllowlist.contains(entry))
          .toList();

      expect(
        missing,
        isEmpty,
        reason:
            'כתובות שקיימות ברשימה המקומפלת אך חסרות ב-'
            'plugin_network_allowlist.txt: $missing',
      );
    },
  );
}
