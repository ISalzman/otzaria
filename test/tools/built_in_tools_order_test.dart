import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tools/built_in_tools_catalog.dart';
import 'package:otzaria/tools/tool_order.dart';

List<String> _ids(List<String> customOrder) =>
    orderedBuiltInTools(customOrder).map((meta) => meta.toolId).toList();

void main() {
  group('orderedBuiltInTools', () {
    test('ללא סדר מותאם — סדר התצוגה של הקטלוג (שדה order)', () {
      final ids = _ids(const []);
      expect(ids.first, 'builtin.calendar');
      // notes=25 יושב צמוד ל"שמור וזכור"=20 ולפני "מדות ושיעורים"=30.
      expect(
        ids.indexOf('builtin.notes'),
        lessThan(ids.indexOf('builtin.measurements')),
      );
      expect(ids.length, kBuiltInToolsCatalog.length);
    });

    test('סדר מותאם מלא נשמר כמו שהוא', () {
      final reversed = _ids(const []).reversed.toList();
      expect(_ids(reversed), reversed);
    });

    test('סדר חלקי — הכלים שצוינו תחילה, השאר בסדר הקטלוג', () {
      final ids = _ids(const ['builtin.gematria', 'builtin.notes']);
      expect(ids.take(2), ['builtin.gematria', 'builtin.notes']);
      expect(ids.length, kBuiltInToolsCatalog.length);
      expect(ids.toSet().length, ids.length);
    });

    test('מזהה שאינו בקטלוג מסונן ואינו מוסיף פריט רפאים', () {
      final ids = _ids(const ['plugin.ghost', 'builtin.gematria']);
      expect(ids.first, 'builtin.gematria');
      expect(ids.contains('plugin.ghost'), isFalse);
      expect(ids.length, kBuiltInToolsCatalog.length);
    });

    test('כפילות בסדר השמור אינה משכפלת כלי', () {
      final ids = _ids(const [
        'builtin.gematria',
        'builtin.gematria',
        'builtin.calendar',
      ]);
      expect(ids.take(2), ['builtin.gematria', 'builtin.calendar']);
      expect(ids.toSet().length, ids.length);
    });

    test('כלי מובנה חדש שאינו בסדר השמור מופיע ואינו נעלם', () {
      final ids = _ids(const ['builtin.gematria']);
      for (final meta in kBuiltInToolsCatalog) {
        expect(ids, contains(meta.toolId));
      }
    });
  });

  group('reorderIdsAroundTarget', () {
    const ids = ['a', 'b', 'c', 'd'];

    test('הפלה אחרי היעד מציבה מיד אחריו', () {
      expect(reorderIdsAroundTarget(ids, 'a', 'c', placeAfter: true), [
        'b',
        'c',
        'a',
        'd',
      ]);
    });

    test('הפלה לפני היעד מציבה מיד לפניו', () {
      expect(reorderIdsAroundTarget(ids, 'd', 'b', placeAfter: false), [
        'a',
        'd',
        'b',
        'c',
      ]);
    });

    test('גרירה אחורה עם placeAfter מציבה אחרי היעד', () {
      expect(reorderIdsAroundTarget(ids, 'd', 'a', placeAfter: true), [
        'a',
        'd',
        'b',
        'c',
      ]);
    });

    test('הפלה לפני הראשון מציבה בראש', () {
      expect(
        reorderIdsAroundTarget(ids, 'c', 'a', placeAfter: false).first,
        'c',
      );
    });

    test('הפלה אחרי האחרון מציבה בסוף', () {
      expect(reorderIdsAroundTarget(ids, 'a', 'd', placeAfter: true).last, 'a');
    });

    test('הפלה על עצמו אינה משנה', () {
      expect(reorderIdsAroundTarget(ids, 'b', 'b', placeAfter: true), ids);
      expect(reorderIdsAroundTarget(ids, 'b', 'b', placeAfter: false), ids);
    });

    test('מזהה חסר אינו משנה ואינו זורק', () {
      expect(reorderIdsAroundTarget(ids, 'x', 'b', placeAfter: true), ids);
      expect(reorderIdsAroundTarget(ids, 'b', 'x', placeAfter: false), ids);
    });

    test('אינו משנה את רשימת הקלט', () {
      final input = List<String>.from(ids);
      reorderIdsAroundTarget(input, 'a', 'c', placeAfter: true);
      expect(input, ids);
    });

    test('שכן צמוד: קדימה ואז אחורה מחזירים לסדר המקורי', () {
      final forward = reorderIdsAroundTarget(ids, 'a', 'b', placeAfter: true);
      expect(forward.take(2), ['b', 'a']);
      final back = reorderIdsAroundTarget(forward, 'a', 'b', placeAfter: false);
      expect(back, ids);
    });
  });

  group('reorderedBuiltInToolIds', () {
    test('הזזה קדימה מציבה את הכלי אחרי שכנו', () {
      final base = _ids(const []);
      final result = reorderedBuiltInToolIds(
        const [],
        base[0],
        base[1],
        placeAfter: true,
      );
      expect(result.take(2), [base[1], base[0]]);
      expect(result.length, base.length);
    });

    test('הזזה אחורה מציבה את הכלי לפני שכנו', () {
      final base = _ids(const []);
      final result = reorderedBuiltInToolIds(
        const [],
        base[2],
        base[1],
        placeAfter: false,
      );
      expect(result.take(3), [base[0], base[2], base[1]]);
    });

    test('הזזה לסוף שומרת את שאר הסדר', () {
      final base = _ids(const []);
      final result = reorderedBuiltInToolIds(
        const [],
        base.first,
        base.last,
        placeAfter: true,
      );
      expect(result.last, base.first);
      expect(result.first, base[1]);
      expect(result.toSet().length, base.length);
    });

    test('מקור ויעד זהים — הסדר אינו משתנה', () {
      final base = _ids(const []);
      expect(
        reorderedBuiltInToolIds(const [], base[3], base[3], placeAfter: true),
        base,
      );
    });

    test('מזהה שאינו קיים — הסדר אינו משתנה', () {
      final base = _ids(const []);
      expect(
        reorderedBuiltInToolIds(const [], 'nope', base[0], placeAfter: true),
        base,
      );
      expect(
        reorderedBuiltInToolIds(const [], base[0], 'nope', placeAfter: false),
        base,
      );
    });

    test('התוצאה תמיד מלאה — גם כשהבסיס השמור חלקי', () {
      final result = reorderedBuiltInToolIds(
        const ['builtin.gematria'],
        'builtin.calendar',
        'builtin.gematria',
        placeAfter: false,
      );
      expect(result.length, kBuiltInToolsCatalog.length);
      expect(result.take(2), ['builtin.calendar', 'builtin.gematria']);
    });

    test('הסדר שנשמר יציב: החלה חוזרת מחזירה את אותה רשימה', () {
      final once = reorderedBuiltInToolIds(
        const [],
        'builtin.gematria',
        'builtin.calendar',
        placeAfter: false,
      );
      expect(_ids(once), once);
    });
  });
}
