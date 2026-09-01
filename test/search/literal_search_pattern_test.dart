import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/utils/literal_search_pattern.dart';

import '../text_book/utils/literal_pattern_test_helper.dart';

void main() {
  group('normalizeLiteralQuery', () {
    test('מסיר ניקוד', () {
      expect(normalizeLiteralQuery('הֲרֵעֹתִי'), 'הרעתי');
    });

    test('ממיר מקף עברי לרווח — זהה לניקוי התוכן', () {
      expect(normalizeLiteralQuery('אשר־שמע'), 'אשר שמע');
    });

    test('ממיר פסק לרווח', () {
      expect(normalizeLiteralQuery('אשר ׀ שמע'), 'אשר שמע');
    });

    test('מכווץ רצפי רווח ומקצץ', () {
      expect(normalizeLiteralQuery('  שמע   ישראל  '), 'שמע ישראל');
    });
  });

  group('stripWordBoundaryWrapper', () {
    test('התאמה חלקית מוצאת מילה בתוך מילה, מלאה לא', () {
      const line = 'את השמים ואת הארץ';
      expect(literalPattern('שמים').hasMatch(line), isFalse);
      expect(
        literalPattern('שמים', wholeWord: false).hasMatch(line),
        isTrue,
      );
    });

    test('התאמה חלקית עדיין מוצאת מילה שלמה', () {
      expect(
        literalPattern('שמים', wholeWord: false).hasMatch('את שמים וארץ'),
        isTrue,
      );
    });

    test('שומרת על סובלנות לניקוד ולגרשיים', () {
      expect(
        literalPattern('הרעתי', wholeWord: false).hasMatch('וְהַרֵעֹתִי'),
        isTrue,
      );
      expect(
        literalPattern('רשי', wholeWord: false).hasMatch('שיטת רש״י'),
        isFalse,
      );
      expect(
        literalPattern('רשי', wholeWord: false).hasMatch('שיטת רשי'),
        isTrue,
      );
    });

    test('גבול פנימי בין מילים נשמר בהתאמה חלקית', () {
      final pattern = literalPattern('שמע ישראל', wholeWord: false);
      expect(pattern.hasMatch('ושמע ישראלים'), isTrue);
      expect(pattern.hasMatch('שמעישראל'), isFalse);
    });

    test('חותכת את ה-(?! האחרון, לא כזה שבתוך הביטוי', () {
      // תג HTML במפריד בין מילים מכיל (?! משלו — חיתוך לפי המופע הראשון
      // היה קוטע את הביטוי באמצע.
      const source = r'(?<![א-ת])(?:אב<(?!br)[^>]*>גד)(?![א-ת])';
      expect(stripWordBoundaryWrapper(source), r'(?:אב<(?!br)[^>]*>גד)');
    });

    test('מחזירה null כשהמבנה אינו מזוהה', () {
      expect(stripWordBoundaryWrapper('אבג'), isNull);
      expect(stripWordBoundaryWrapper('(?<![א-ת])(?:אבג)'), isNull);
    });
  });
}
