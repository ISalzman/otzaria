import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/utils/plugin_dev_tools_mode.dart';

void main() {
  group('isDevPluginsFlag', () {
    test('מזהה את כל צורות הכתיבה של הדגל', () {
      expect(isDevPluginsFlag('--dev-plugins'), isTrue);
      expect(isDevPluginsFlag('/dev-plugins'), isTrue);
      expect(isDevPluginsFlag('dev-plugins'), isTrue);
      expect(isDevPluginsFlag('--dev_plugins'), isTrue);
      expect(isDevPluginsFlag('--DEV-PLUGINS'), isTrue);
      expect(isDevPluginsFlag('  --dev-plugins  '), isTrue);
    });

    test('לא מזהה ארגומנטים אחרים', () {
      expect(isDevPluginsFlag('--dev'), isFalse);
      expect(isDevPluginsFlag('--plugins'), isFalse);
      expect(isDevPluginsFlag('pack-plugin'), isFalse);
      expect(isDevPluginsFlag('otzaria://plugin/install'), isFalse);
      expect(isDevPluginsFlag('C:\\path\\to\\file.otzplugin'), isFalse);
      expect(isDevPluginsFlag(''), isFalse);
    });
  });

  group('PluginDevToolsMode.initFromArgs', () {
    tearDown(PluginDevToolsMode.resetForTesting);

    test('דגל בין שאר הארגומנטים נקלט', () {
      PluginDevToolsMode.initFromArgs(['some.otzplugin', '--dev-plugins']);
      expect(PluginDevToolsMode.launchFlagForTesting, isTrue);
      expect(PluginDevToolsMode.enabled, isTrue);
    });

    test('בלי הדגל — לא נקלט', () {
      PluginDevToolsMode.initFromArgs(['some.otzplugin']);
      expect(PluginDevToolsMode.launchFlagForTesting, isFalse);
    });
  });
}
