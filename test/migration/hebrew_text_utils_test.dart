import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/generator/hebrew_text_utils.dart';

void main() {
  // בראשית עם ניקוד מלא
  const withNikud = 'בְּרֵאשִׁית';
  // בראשית עם ניקוד וטעמים (טיפחא U+0596 על השי"ן)
  const withNikudAndTeamim = 'בְּרֵאשִׁ֖ית';
  // מילה עם מתג (U+05BD)
  const withMeteg = 'הָֽאָרֶץ';

  group('removeNikud', () {
    test('מסיר ניקוד מטקסט', () {
      expect(removeNikud(withNikud), 'בראשית');
    });

    test('מסיר מתג כברירת מחדל', () {
      expect(removeNikud(withMeteg), 'הארץ');
    });

    test('משאיר מתג כאשר includeMeteg=false', () {
      expect(removeNikud(withMeteg, includeMeteg: false), 'הֽארץ');
    });

    test('לא מסיר טעמים', () {
      expect(removeNikud(withNikudAndTeamim), 'בראש֖ית');
    });

    test('קלט null או ריק מחזיר מחרוזת ריקה', () {
      expect(removeNikud(null), '');
      expect(removeNikud(''), '');
    });

    test('טקסט ללא ניקוד מוחזר כמו שהוא', () {
      expect(removeNikud('בראשית'), 'בראשית');
    });
  });

  group('removeTeamim', () {
    test('מסיר טעמים ומשאיר ניקוד', () {
      expect(removeTeamim(withNikudAndTeamim), withNikud);
    });

    test('קלט null או ריק מחזיר מחרוזת ריקה', () {
      expect(removeTeamim(null), '');
      expect(removeTeamim(''), '');
    });
  });

  group('removeAllDiacritics', () {
    test('מסיר ניקוד וטעמים יחד', () {
      expect(removeAllDiacritics(withNikudAndTeamim), 'בראשית');
    });

    test('מסיר קמץ קטן (U+05C7)', () {
      expect(removeAllDiacritics('כׇל'), 'כל');
    });

    test('קלט null או ריק מחזיר מחרוזת ריקה', () {
      expect(removeAllDiacritics(null), '');
      expect(removeAllDiacritics(''), '');
    });
  });

  group('containsNikud / containsTeamim', () {
    test('מזהה ניקוד', () {
      expect(containsNikud(withNikud), isTrue);
      expect(containsNikud('בראשית'), isFalse);
      expect(containsNikud(null), isFalse);
      expect(containsNikud(''), isFalse);
    });

    test('מזהה מתג כניקוד', () {
      expect(containsNikud(withMeteg), isTrue);
    });

    test('מזהה טעמים', () {
      expect(containsTeamim(withNikudAndTeamim), isTrue);
      expect(containsTeamim(withNikud), isFalse);
      expect(containsTeamim(null), isFalse);
    });
  });

  group('containsMaqaf / replaceMaqaf', () {
    const withMaqaf = 'על־כן';

    test('מזהה מקף עברי', () {
      expect(containsMaqaf(withMaqaf), isTrue);
      expect(containsMaqaf('על-כן'), isFalse);
      expect(containsMaqaf(null), isFalse);
    });

    test('מחליף מקף ברווח כברירת מחדל', () {
      expect(replaceMaqaf(withMaqaf), 'על כן');
    });

    test('מחליף מקף במחרוזת מותאמת', () {
      expect(replaceMaqaf(withMaqaf, replacement: '-'), 'על-כן');
    });

    test('קלט null או ריק מחזיר מחרוזת ריקה', () {
      expect(replaceMaqaf(null), '');
      expect(replaceMaqaf(''), '');
    });
  });
}
