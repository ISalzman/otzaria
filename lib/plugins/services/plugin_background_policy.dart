import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';

/// האם תוסף משתמש במסלול התאימות שמרים מנוע מיד בעליית אוצריא.
bool usesLegacyStartupRunner(InstalledPlugin plugin) {
  final startup = plugin.manifest.startup;
  return plugin.enabled &&
      plugin.runOnStartupGranted &&
      plugin.manifest.permissions.contains(pluginRunOnStartupPermission) &&
      (startup == null || startup.isEmpty);
}
