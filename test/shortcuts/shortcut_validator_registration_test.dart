import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/shortcuts/shortcut_validator.dart';

void main() {
  group('ShortcutValidator - רישום קיצורי החלוניות', () {
    test('המפתחות החדשים נמצאים ב-shortcutKeys', () {
      expect(
        ShortcutValidator.shortcutKeys,
        containsAll(<String>[
          'key-shortcut-toggle-nav-pane',
          'key-shortcut-toggle-commentators-pane',
          'key-shortcut-open-commentators-tab',
        ]),
      );
    });

    test('ברירות מחדל: Ctrl+Shift+L לניווט, Ctrl+Shift+C למפרשים', () {
      expect(
        ShortcutValidator.defaultShortcuts['key-shortcut-toggle-nav-pane'],
        'ctrl+shift+l',
      );
      expect(
        ShortcutValidator
            .defaultShortcuts['key-shortcut-toggle-commentators-pane'],
        'ctrl+shift+c',
      );
    });

    test('פתיחת כרטיסיית מפרשים — ללא ברירת מחדל (המשתמש יבחר)', () {
      expect(
        ShortcutValidator
            .defaultShortcuts['key-shortcut-open-commentators-tab'],
        '',
      );
    });

    test('שמות תצוגה בעברית קיימים', () {
      expect(
        ShortcutValidator.shortcutNames['key-shortcut-toggle-nav-pane'],
        'פתח/סגור חלונית ניווט',
      );
      expect(
        ShortcutValidator
            .shortcutNames['key-shortcut-toggle-commentators-pane'],
        'פתח/סגור חלונית מפרשים',
      );
      expect(
        ShortcutValidator.shortcutNames['key-shortcut-open-commentators-tab'],
        'פתח כרטיסיית מפרשים',
      );
    });

    test('Ctrl+Shift+C ו-Ctrl+Shift+L אינם מתנגשים עם קיצורים אחרים', () {
      // עוברים על כל ברירות המחדל ומוודאים שלא יש כפילות עם הקיצורים החדשים
      const newShortcuts = {'ctrl+shift+l', 'ctrl+shift+c'};
      final clashes = <String, List<String>>{};
      for (final entry in ShortcutValidator.defaultShortcuts.entries) {
        if (newShortcuts.contains(entry.value) &&
            entry.key != 'key-shortcut-toggle-nav-pane' &&
            entry.key != 'key-shortcut-toggle-commentators-pane') {
          clashes.putIfAbsent(entry.value, () => []).add(entry.key);
        }
      }
      expect(clashes, isEmpty,
          reason: 'נמצאו התנגשויות עם הקיצורים החדשים: $clashes');
    });
  });
}
