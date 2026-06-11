import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/utils/hebrew_morphology.dart';

void main() {
  group('generatePrefixVariations', () {
    test('מחזיר את המילה עצמה כאיבר הראשון', () {
      final variations = HebrewMorphology.generatePrefixVariations('תורה');
      expect(variations.first, 'תורה');
    });

    test('כולל קידומות בסיסיות וצירופי קידומות', () {
      final variations = HebrewMorphology.generatePrefixVariations('תורה');
      expect(variations, contains('התורה'));
      expect(variations, contains('בתורה'));
      expect(variations, contains('ובתורה'));
      expect(variations, contains('כשהתורה'));
      expect(variations, contains('ולכשהתורה'));
    });

    test('אין כפילויות ברשימה', () {
      final variations = HebrewMorphology.generatePrefixVariations('תורה');
      expect(variations.toSet().length, variations.length);
    });

    test('מילה ריקה מחזירה רשימה עם מחרוזת ריקה בלבד', () {
      expect(HebrewMorphology.generatePrefixVariations(''), ['']);
    });
  });

  group('generateSuffixVariations', () {
    test('כולל סיומות ריבוי ושייכות', () {
      final variations = HebrewMorphology.generateSuffixVariations('דבר');
      expect(variations, contains('דבר'));
      expect(variations, contains('דברים'));
      expect(variations, contains('דברות'));
      expect(variations, contains('דברינו'));
      expect(variations, contains('דברותיהם'));
    });

    test('מילה ריקה מחזירה רשימה עם מחרוזת ריקה בלבד', () {
      expect(HebrewMorphology.generateSuffixVariations(''), ['']);
    });
  });

  group('generateFullMorphologicalVariations', () {
    test('כולל את המילה עצמה וצירופי קידומת+סיומת', () {
      final variations =
          HebrewMorphology.generateFullMorphologicalVariations('דבר');
      expect(variations, contains('דבר'));
      // קידומת ריקה + סיומת
      expect(variations, contains('דברים'));
      // קידומת + סיומת
      expect(variations, contains('ודברים'));
      expect(variations, contains('שהדברים'));
    });

    test('מילה ריקה מחזירה רשימה עם מחרוזת ריקה בלבד', () {
      expect(HebrewMorphology.generateFullMorphologicalVariations(''), ['']);
    });
  });

  group('createPrefixRegexPattern', () {
    test('הדפוס תופס את המילה עם ובלי קידומות', () {
      final pattern = HebrewMorphology.createPrefixRegexPattern('תורה');
      final regex = RegExp('^$pattern\$');
      expect(regex.hasMatch('תורה'), isTrue);
      expect(regex.hasMatch('התורה'), isTrue);
      expect(regex.hasMatch('ובתורה'), isTrue);
      expect(regex.hasMatch('כשהתורה'), isTrue);
    });

    test('הדפוס לא תופס מילה עם קידומת לא דקדוקית', () {
      final pattern = HebrewMorphology.createPrefixRegexPattern('תורה');
      final regex = RegExp('^$pattern\$');
      expect(regex.hasMatch('קתורה'), isFalse);
      expect(regex.hasMatch('תורת'), isFalse);
    });

    test('תווים מיוחדים במילה עוברים escape', () {
      final pattern = HebrewMorphology.createPrefixRegexPattern('א.ב');
      final regex = RegExp('^$pattern\$');
      expect(regex.hasMatch('א.ב'), isTrue);
      expect(regex.hasMatch('אXב'), isFalse);
    });
  });

  group('createSuffixRegexPattern', () {
    test('הדפוס תופס את המילה עם ובלי סיומות', () {
      final pattern = HebrewMorphology.createSuffixRegexPattern('דבר');
      final regex = RegExp('^$pattern\$');
      expect(regex.hasMatch('דבר'), isTrue);
      expect(regex.hasMatch('דברים'), isTrue);
      expect(regex.hasMatch('דברותיהם'), isTrue);
    });

    test('הדפוס לא תופס סיומת לא דקדוקית', () {
      final pattern = HebrewMorphology.createSuffixRegexPattern('דבר');
      final regex = RegExp('^$pattern\$');
      expect(regex.hasMatch('דברקקק'), isFalse);
    });
  });

  group('createFullMorphologicalRegexPattern', () {
    test('הדפוס תופס קידומת וסיומת יחד', () {
      final pattern =
          HebrewMorphology.createFullMorphologicalRegexPattern('דבר');
      final regex = RegExp('^$pattern\$');
      expect(regex.hasMatch('דבר'), isTrue);
      expect(regex.hasMatch('והדברים'), isTrue);
      expect(regex.hasMatch('שהדברות'), isTrue);
    });
  });

  group('hasGrammaticalPrefix / hasGrammaticalSuffix', () {
    test('מזהה קידומת דקדוקית', () {
      expect(HebrewMorphology.hasGrammaticalPrefix('הבית'), isTrue);
      expect(HebrewMorphology.hasGrammaticalPrefix('תורה'), isFalse);
      expect(HebrewMorphology.hasGrammaticalPrefix(''), isFalse);
    });

    test('מזהה סיומת דקדוקית', () {
      expect(HebrewMorphology.hasGrammaticalSuffix('ספרים'), isTrue);
      expect(HebrewMorphology.hasGrammaticalSuffix('אב'), isFalse);
      expect(HebrewMorphology.hasGrammaticalSuffix(''), isFalse);
    });
  });

  group('extractRoot', () {
    test('מסיר סיומת ממילה ללא קידומת', () {
      expect(HebrewMorphology.extractRoot('ספרים'), 'ספר');
    });

    test('מסיר קידומת ומשאיר את שאר המילה', () {
      expect(HebrewMorphology.extractRoot('הספרים'), 'ספר');
      expect(HebrewMorphology.extractRoot('והספרים'), 'ספר');
    });

    test('מסיר קידומת וסיומת יחד', () {
      expect(HebrewMorphology.extractRoot('ותורתו'), 'תורת');
    });

    test('מילה ללא קידומת וסיומת מוחזרת כמו שהיא', () {
      expect(HebrewMorphology.extractRoot('דג'), 'דג');
    });

    test('מילה ריקה מוחזרת כמו שהיא', () {
      expect(HebrewMorphology.extractRoot(''), '');
    });
  });

  group('generateFullPartialSpellingVariations', () {
    test('יוצר וריאציות כתיב מלא/חסר עבור יו"ד וּוא"ו', () {
      final variations =
          HebrewMorphology.generateFullPartialSpellingVariations('אליהו');
      expect(variations, contains('אליהו'));
      expect(variations, contains('אלהו'));
      expect(variations, contains('אליה'));
      expect(variations, contains('אלה'));
    });

    test('מילה ללא אותיות אופציונליות מחזירה את עצמה בלבד', () {
      expect(
        HebrewMorphology.generateFullPartialSpellingVariations('דג'),
        ['דג'],
      );
    });
  });

  group('createFullPartialSpellingPattern', () {
    test('הדפוס תופס את כל וריאציות הכתיב', () {
      final pattern =
          HebrewMorphology.createFullPartialSpellingPattern('אליהו');
      final regex = RegExp(pattern);
      expect(regex.hasMatch('אליהו'), isTrue);
      expect(regex.hasMatch('אלהו'), isTrue);
      expect(regex.hasMatch('אברהם'), isFalse);
    });
  });

  group('getBasicPrefixes / getBasicSuffixes', () {
    test('מחזירים רשימות לא ריקות', () {
      expect(HebrewMorphology.getBasicPrefixes(), isNotEmpty);
      expect(HebrewMorphology.getBasicSuffixes(), isNotEmpty);
    });
  });
}
