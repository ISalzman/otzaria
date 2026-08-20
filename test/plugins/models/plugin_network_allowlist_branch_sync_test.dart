import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/models/plugin_network_allowlist.dart';

/// מקור האמת היחיד לגישת רשת של תוספים הוא `plugin_network_allowlist.txt`
/// שבשורש הריפו: האפליקציה מושכת אותו מענף dev בזמן ריצה, והרשימה המקומפלת
/// (`plugin_network_allowlist.g.dart`) מחוללת ממנו אוטומטית בכל בנייה.
/// הבדיקה מוודאת שהעותק המקומפל אכן זהה לקובץ — כלומר ששניהם משקפים את
/// אותו קובץ ושהמחולל רץ אחרי עריכתו.
///
/// הבדיקה קוראת את הקובץ המקומי ולא מושכת מ-GitHub: כך היא בודקת את התוכן
/// של ה-PR עצמו ולא את מה שכבר ממוזג ב-dev, ואינה תלויה ברשת.
void main() {
  test('הרשימה המקומפלת זהה לקובץ plugin_network_allowlist.txt', () {
    final file = File('plugin_network_allowlist.txt');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'הקובץ ${file.path} חייב להתקיים בשורש הריפו — הוא מקור האמת '
          'שהאפליקציה מושכת מענף dev ושממנו מחוללת הרשימה המקומפלת',
    );

    final fileAllowlist = parsePluginNetworkAllowlistText(
      file.readAsStringSync(),
    );
    expect(
      pluginNetworkAllowlist,
      fileAllowlist,
      reason:
          'הרשימה המקומפלת אינה מסונכרנת עם plugin_network_allowlist.txt — '
          'הרץ: dart run tool/generate_plugin_network_allowlist.dart',
    );
  });

  test('כל הערכים בקובץ הם קידומות URL עם scheme מלא (http/https)', () {
    final entries = parsePluginNetworkAllowlistText(
      File('plugin_network_allowlist.txt').readAsStringSync(),
    );
    expect(entries, isNotEmpty);

    final invalid = entries.where((entry) {
      final uri = Uri.tryParse(entry);
      return uri == null || (uri.scheme != 'http' && uri.scheme != 'https');
    }).toList();
    expect(
      invalid,
      isEmpty,
      reason: 'ערכים ללא scheme מלא לא ייאכפו כלל: $invalid',
    );
  });
}
