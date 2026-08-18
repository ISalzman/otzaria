// מחולל הרשימה המקומפלת של היתרי הרשת לתוספים: קורא את
// `plugin_network_allowlist.txt` (מקור האמת היחיד) ומחולל ממנו קבוע Dart,
// כך שהגיבוי הלא-מקוון מקומפל לבינארי ואינו נגיש לעריכה אצל המשתמש.
//
// הלוגיקה משותפת ל-`tool/generate_plugin_network_allowlist.dart` (ידני / CI)
// ול-`hook/build.dart` (רץ אוטומטית בכל בנייה).

import 'dart:io';

const String allowlistSourceRelativePath = 'plugin_network_allowlist.txt';
const String allowlistOutputRelativePath =
    'lib/plugins/models/plugin_network_allowlist.g.dart';

/// שגיאת ולידציה בקובץ ה-allowlist.
class PluginNetworkAllowlistError implements Exception {
  PluginNetworkAllowlistError(this.message);

  final String message;

  @override
  String toString() => message;
}

class GenerateAllowlistResult {
  const GenerateAllowlistResult({
    required this.changed,
    required this.outputPath,
    required this.entriesCount,
  });

  final bool changed;
  final String outputPath;
  final int entriesCount;
}

/// מפרק את קובץ ה-allowlist: שורה = קידומת URL; ריקות ו-`#` מדולגות.
/// חייב להישאר זהה ל-`parsePluginNetworkAllowlistText` שבקוד האפליקציה —
/// ההתאמה נאכפת ב-test/plugins/models/plugin_network_allowlist_branch_sync_test.dart.
List<String> parseAllowlistSource(String source) => source
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty && !line.startsWith('#'))
    .toList();

/// מחולל את `plugin_network_allowlist.g.dart` מתוך קובץ המקור תחת
/// [packageRoot]. זורק [PluginNetworkAllowlistError] על קובץ חסר או ערך
/// שאינו קידומת http/https תקינה.
GenerateAllowlistResult generatePluginNetworkAllowlist(Directory packageRoot) {
  final sourceFile = File.fromUri(
    packageRoot.uri.resolve(allowlistSourceRelativePath),
  );
  if (!sourceFile.existsSync()) {
    throw PluginNetworkAllowlistError(
      '$allowlistSourceRelativePath לא נמצא בשורש הריפו — '
      'הוא מקור האמת של היתרי הרשת לתוספים',
    );
  }

  final entries = parseAllowlistSource(sourceFile.readAsStringSync());
  final invalid = entries.where((entry) {
    final uri = Uri.tryParse(entry);
    return uri == null || (uri.scheme != 'http' && uri.scheme != 'https');
  }).toList();
  if (invalid.isNotEmpty) {
    throw PluginNetworkAllowlistError(
      '$allowlistSourceRelativePath: ערכים ללא scheme מלא (http/https) '
      'לא ייאכפו כלל — ${invalid.join(', ')}',
    );
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT MODIFY BY HAND.')
    ..writeln('// dart format off')
    ..writeln('//')
    ..writeln('// מחולל מ-$allowlistSourceRelativePath — ערוך שם, לא כאן.')
    ..writeln()
    ..writeln('/// העותק המקומפל של קובץ ההיתרים — גיבוי לא-מקוון בלבד;')
    ..writeln(
      '/// מקור האמת הוא הקובץ בענף dev (ראו plugin_network_allowlist.dart).',
    )
    ..writeln('const List<String> pluginNetworkAllowlist = <String>[');
  for (final entry in entries) {
    buffer.writeln(
      "  '${entry.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}',",
    );
  }
  buffer.writeln('];');

  final newContent = buffer.toString();
  final outputFile = File.fromUri(
    packageRoot.uri.resolve(allowlistOutputRelativePath),
  );
  final changed =
      !outputFile.existsSync() || outputFile.readAsStringSync() != newContent;
  if (changed) {
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(newContent);
  }

  return GenerateAllowlistResult(
    changed: changed,
    outputPath: allowlistOutputRelativePath,
    entriesCount: entries.length,
  );
}
