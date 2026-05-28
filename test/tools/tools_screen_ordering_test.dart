import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/tools_screen.dart';

/// descriptor מינימלי לבדיקת המיון בלבד — ה-pageBuilder לעולם לא נקרא כאן.
BuiltInToolDescriptor _desc(String id, int order) => BuiltInToolDescriptor(
      toolId: id,
      label: id,
      order: order,
      pageBuilder: () => const SizedBox.shrink(),
    );

void main() {
  group('sortToolDescriptorsStably', () {
    test('ממיין לפי order עולה', () {
      final list = [_desc('c', 30), _desc('a', 10), _desc('b', 20)];
      sortToolDescriptorsStably(list);
      expect(list.map((d) => d.toolId).toList(), ['a', 'b', 'c']);
    });

    test('שומר על הסדר היחסי של כלים בעלי order זהה (יציבות)', () {
      // מדמה את התרחיש האמיתי: כלי מובנה (order ייחודי) ואחריו כמה תוספים
      // שכולם בברירת המחדל 900 — סדרם הגיע כבר דטרמיניסטית מה-repository
      // (order → installedAt → pluginId) ואסור שהמיון ישבש אותו.
      final list = [
        _desc('builtin.calendar', 10),
        _desc('plugin.aaa', 900),
        _desc('plugin.bbb', 900),
        _desc('plugin.ccc', 900),
      ];
      sortToolDescriptorsStably(list);
      expect(
        list.map((d) => d.toolId).toList(),
        ['builtin.calendar', 'plugin.aaa', 'plugin.bbb', 'plugin.ccc'],
      );
    });

    test('אינו ממיין אלפביתית בעלי order זהה — שומר את סדר ההכנסה', () {
      // רגרסיה ל-`List.sort` הלא-יציב: הקלט מסודר ccc,bbb,aaa (לא אלפבית).
      // מיון יציב חייב להשאיר אותם בדיוק כך; מיון לא-יציב/אלפביתי היה
      // מחזיר aaa,bbb,ccc — בדיוק התסמין ש"נדמה" למשתמש שהוא רואה.
      final list = [
        _desc('plugin.ccc', 900),
        _desc('plugin.bbb', 900),
        _desc('plugin.aaa', 900),
        _desc('builtin.notes', 40),
      ];
      sortToolDescriptorsStably(list);
      expect(
        list.map((d) => d.toolId).toList(),
        ['builtin.notes', 'plugin.ccc', 'plugin.bbb', 'plugin.aaa'],
      );
    });

    test('רשימה ריקה אינה זורקת', () {
      final list = <ToolDescriptor>[];
      expect(() => sortToolDescriptorsStably(list), returnsNormally);
      expect(list, isEmpty);
    });
  });
}
