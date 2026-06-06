import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/page_shape/utils/default_commentators.dart';

/// טסטים למיפוי מפרשי ברירת המחדל ל-4 מיקומי צורת הדף:
/// position 0→ימין, 1→שמאל, 2→תחתון, 3→תחתון-ימני. position חסר → מיקום ריק.
/// התרגומים ממולאים אחרי ה-position המקסימלי של המפרשים.
void main() {
  ({String title, int position}) c(String title, int position) =>
      (title: title, position: position);

  group('DefaultCommentators.mapToPageShape', () {
    test('תורה: מפרש בימין, תרגום בשמאל', () {
      final result =
          DefaultCommentators.mapToPageShape([c('רש"י', 0)], ['תרגום אונקלוס']);

      expect(result['right'], 'רש"י');
      expect(result['left'], 'תרגום אונקלוס');
      expect(result['bottom'], isNull);
      expect(result['bottomRight'], isNull);
    });

    test('בבלי ללא תרגום: המפרש השני נכנס לשמאל', () {
      final result = DefaultCommentators.mapToPageShape(
        [c('רש"י', 0), c('תוספות', 1)],
        [],
      );

      expect(result['right'], 'רש"י');
      expect(result['left'], 'תוספות');
      expect(result['bottom'], isNull);
      expect(result['bottomRight'], isNull);
    });

    test('ארבעה מפרשים ללא תרגום ממלאים את כל המיקומים לפי הסדר', () {
      final result = DefaultCommentators.mapToPageShape(
        [
          c('רש"י', 0),
          c('מצודת דוד', 1),
          c('מצודת ציון', 2),
          c('רד"ק', 3),
        ],
        [],
      );

      expect(result['right'], 'רש"י');
      expect(result['left'], 'מצודת דוד');
      expect(result['bottom'], 'מצודת ציון');
      expect(result['bottomRight'], 'רד"ק');
    });

    test('שני מפרשים + תרגום: מפרשים בימין ובשמאל, התרגום בתחתון', () {
      final result = DefaultCommentators.mapToPageShape(
        [c('רש"י', 0), c('רד"ק', 1)],
        ['תרגום אונקלוס'],
      );

      expect(result['right'], 'רש"י');
      expect(result['left'], 'רד"ק');
      expect(result['bottom'], 'תרגום אונקלוס');
      expect(result['bottomRight'], isNull);
    });

    test('slot ריק (position מדולג): המיקום נשאר ריק והמפרש הבא במקומו', () {
      // מפרש ב-position 0 (ימין), דילוג על 1 (שמאל), מפרש ב-position 2 (תחתון)
      final result = DefaultCommentators.mapToPageShape(
        [c('מפרש א', 0), c('מפרש ב', 2)],
        [],
      );

      expect(result['right'], 'מפרש א');
      expect(result['left'], isNull); // ה-slot הריק נשמר
      expect(result['bottom'], 'מפרש ב');
      expect(result['bottomRight'], isNull);
    });

    test('רשימות ריקות מחזירות null בכל המיקומים', () {
      final result = DefaultCommentators.mapToPageShape([], []);

      expect(result['right'], isNull);
      expect(result['left'], isNull);
      expect(result['bottom'], isNull);
      expect(result['bottomRight'], isNull);
    });
  });
}
