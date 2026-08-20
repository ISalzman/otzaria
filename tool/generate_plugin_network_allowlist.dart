// ignore_for_file: avoid_print
//
// סקריפט בנייה: מחולל את lib/plugins/models/plugin_network_allowlist.g.dart
// מתוך plugin_network_allowlist.txt שבשורש הריפו, ומוודא את תקינות הערכים.
//
// הפעלה ידנית:  `dart run tool/generate_plugin_network_allowlist.dart`
//
// הלוגיקה עצמה ב-`tool/src/plugin_network_allowlist_generator.dart`,
// ומשותפת עם `hook/build.dart` (שרץ אוטומטית בכל בנייה).

import 'dart:io';

import 'src/plugin_network_allowlist_generator.dart';

void main(List<String> args) {
  try {
    final result = generatePluginNetworkAllowlist(Directory.current);
    if (result.changed) {
      stdout.writeln(
        'Generated ${result.outputPath} with ${result.entriesCount} entry/ies.',
      );
    } else {
      stdout.writeln(
        'Allowlist up-to-date: ${result.outputPath} '
        '(${result.entriesCount} entries).',
      );
    }
  } on PluginNetworkAllowlistError catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }
}
