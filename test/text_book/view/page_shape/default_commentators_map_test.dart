import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/view/page_shape/utils/default_commentators.dart';

/// טסטים למיפוי מפרשי ברירת המחדל ל-4 מיקומי צורת הדף (דרישה ב):
/// מפרשים ותרגומים מאוחדים לפי position וממולאים לפי הסדר:
/// ימין, שמאל, תחתון, תחתון-ימני.
void main() {
  group('DefaultCommentators.mapToPageShape', () {
    test('תורה: מפרש בימין, תרגום בשמאל', () {
      final result =
          DefaultCommentators.mapToPageShape(['רש"י'], ['תרגום אונקלוס']);

      expect(result['right'], 'רש"י');
      expect(result['left'], 'תרגום אונקלוס');
      expect(result['bottom'], isNull);
      expect(result['bottomRight'], isNull);
    });

    test('בבלי ללא תרגום: המפרש השני נכנס לשמאל', () {
      final result = DefaultCommentators.mapToPageShape(['רש"י', 'תוספות'], []);

      expect(result['right'], 'רש"י');
      expect(result['left'], 'תוספות');
      expect(result['bottom'], isNull);
      expect(result['bottomRight'], isNull);
    });

    test('ארבעה מפרשים ללא תרגום ממלאים את כל המיקומים לפי הסדר', () {
      final result = DefaultCommentators.mapToPageShape(
        ['רש"י', 'מצודת דוד', 'מצודת ציון', 'רד"ק'],
        [],
      );

      expect(result['right'], 'רש"י');
      expect(result['left'], 'מצודת דוד');
      expect(result['bottom'], 'מצודת ציון');
      expect(result['bottomRight'], 'רד"ק');
    });

    test('שני מפרשים + תרגום: מפרשים בימין ובשמאל, התרגום בתחתון', () {
      final result = DefaultCommentators.mapToPageShape(
        ['רש"י', 'רד"ק'],
        ['תרגום אונקלוס'],
      );

      expect(result['right'], 'רש"י');
      expect(result['left'], 'רד"ק');
      expect(result['bottom'], 'תרגום אונקלוס');
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
