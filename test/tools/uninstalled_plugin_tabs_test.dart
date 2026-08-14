import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';
import 'package:otzaria/tools/open_tool_tab.dart';

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
}
