// ignore_for_file: avoid_print
import 'dart:io';

import 'package:otzaria/plugins/services/plugin_packager_cli.dart';

/// Wrapper דק סביב [PluginPackagerCli.run] — קוד CLI אמיתי חי בספרייה
/// המשותפת כדי שמסלול ה-`dart run` ומסלול ה-`otzaria.exe pack-plugin`
/// יתנהגו זהה לחלוטין (אותם דגלים, אותם קודי יציאה, אותו פלט).
void main(List<String> args) async {
  final code = await PluginPackagerCli.run(args);
  exit(code);
}
