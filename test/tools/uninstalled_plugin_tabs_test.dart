import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';
import 'package:otzaria/tools/open_tool_tab.dart';

InstalledPlugin _plugin(String id) => InstalledPlugin(
  pluginId: id,
  name: id,
  version: '1.0.0',
  installPath: '/plugins/$id',
  entrypointPath: 'index.html',
  enabled: true,
  pinned: false,
  manifest: PluginManifest.fromJson({
    'schemaVersion': 1,
    'id': id,
    'name': id,
    'version': '1.0.0',
    'entrypoint': 'index.html',
    'contributes': {
      'toolTab': {'title': id},
    },
  }),
  installedAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// בדיקות רגרסיה: מחיקת תוסף חייבת לסגור את הכרטיסיה הפתוחה שלו, ולא להשאיר
/// כרטיסיה עם "הכלי אינו זמין" שהמשתמש צריך לסגור ידנית.
void main() {
  group('orphanedPluginToolTabs', () {
    test('תוסף שהוסר — הכרטיסיה שלו נסגרת', () {
      final removed = ToolTab(
        toolId: 'otzaria.plugins_directory',
        title: 'חנות',
      );
      final kept = ToolTab(toolId: 'other.plugin', title: 'אחר');

      final orphaned = orphanedPluginToolTabs(
        [removed, kept],
        [
          'other.plugin',
        ],
      );

      expect(orphaned, [removed]);
    });

    test('תוסף שעדיין מותקן — הכרטיסיה נשארת (גם אם מושבת/מוסתר)', () {
      // הרשימה שמגיעה מ-PluginSystemLoaded כוללת גם מושבתים ומוסתרים.
      final tab = ToolTab(toolId: 'some.plugin', title: 'תוסף');

      expect(orphanedPluginToolTabs([tab], ['some.plugin']), isEmpty);
    });

    test('כלי מובנה אינו נסגר גם כשאינו ברשימת התוספים', () {
      final builtIn = ToolTab(toolId: 'builtin.calendar', title: 'לוח שנה');

      expect(orphanedPluginToolTabs([builtIn], const []), isEmpty);
    });

    test('אין תוספים מותקנים — כל כרטיסיות התוספים נסגרות', () {
      final first = ToolTab(toolId: 'a.plugin', title: 'א');
      final second = ToolTab(toolId: 'b.plugin', title: 'ב');
      final builtIn = ToolTab(toolId: 'builtin.gematria', title: 'גימטריה');

      expect(orphanedPluginToolTabs([first, builtIn, second], const []), [
        first,
        second,
      ]);
    });
  });

  group('orphanedPluginToolTabsForState', () {
    test('רשימת התוספים עדיין נטענת — לא סוגרים כלום', () {
      // תרחיש העלייה: הכרטיסיות משוחזרות לפני שרישום התוספים נקרא. סגירה
      // כאן הייתה מוחקת למשתמש כרטיסיות תקינות.
      final tab = ToolTab(toolId: 'some.plugin', title: 'תוסף');

      expect(
        orphanedPluginToolTabsForState([tab], PluginSystemInitial()),
        isEmpty,
      );
      expect(
        orphanedPluginToolTabsForState([tab], PluginSystemLoading()),
        isEmpty,
      );
    });

    test('סביבת עבודה אחרת נטענת אחרי המחיקה — הכרטיסיה נסגרת', () {
      final removed = ToolTab(toolId: 'removed.plugin', title: 'שהוסר');
      final kept = ToolTab(toolId: 'kept.plugin', title: 'שנשאר');

      final orphaned = orphanedPluginToolTabsForState(
        [removed, kept],
        PluginSystemLoaded([_plugin('kept.plugin')]),
      );

      expect(orphaned, [removed]);
    });
  });
}
