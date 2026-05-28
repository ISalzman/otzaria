import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/search_query_builder.dart';
import 'package:otzaria/search/utils/regex_patterns.dart';

/// טסטים שמכריעים אובייקטיבית את השאלה: האם 'חלק ממילה' ו'שגיאות כתיב'
/// מרחיבים את החיפוש או מגבילים אותו.
///
/// המנוע (Tantivy) מתאים כל ביטוי ב-regexTerms מול **טוקן שלם** — כלומר
/// עיגון משתמע של `^...$`. לכן אנו מדמים כאן את אותה סמנטיקה: ביטוי "תופס"
/// טוקן רק אם הוא מתאים לכולו.
///
/// אם התבנית עם אפשרות תופסת על-קבוצה של הטוקנים שהמילה הבסיסית תופסת
/// (כולל הטוקן המקורי + טוקנים נוספים) → האפשרות **מרחיבה**.
/// אם היא תופסת תת-קבוצה (פחות טוקנים) → האפשרות **מגבילה**.
void main() {
  // מדמה את עיגון-הטוקן-המלא של Tantivy: התאמה רק אם הביטוי מכסה את כל הטוקן.
  bool tokenMatches(String pattern, String token) {
    return RegExp('^(?:$pattern)\$').hasMatch(token);
  }

  // התבנית הבסיסית (חיפוש מדויק, ללא אפשרויות) — בדיוק מה שהמנוע מקבל
  // עבור מילה בודדת ללא אפשרויות מתקדמות.
  String exactPattern(String word) =>
      SearchQueryBuilder.buildAdvancedQuery([word], null, null).first;

  String partialWordPattern(String word) =>
      SearchQueryBuilder.buildAdvancedQuery(
        [word],
        null,
        {
          SearchQueryBuilder.buildWordKey(word, 0): {'חלק ממילה': true}
        },
      ).first;

  String typoPattern(String word) => SearchQueryBuilder.buildAdvancedQuery(
        [word],
        null,
        {
          SearchQueryBuilder.buildWordKey(word, 0): {
            SearchQueryBuilder.typoToleranceOptionKey: true
          }
        },
      ).first;

  group('חלק ממילה — מרחיב, לא מגביל', () {
    test('הטוקן המקורי עדיין נתפס (תנאי הכרחי להרחבה)', () {
      const word = 'תורה';
      expect(tokenMatches(exactPattern(word), word), isTrue,
          reason: 'בסיס: המילה המדויקת חייבת להיתפס');
      expect(tokenMatches(partialWordPattern(word), word), isTrue,
          reason: 'עם "חלק ממילה" הטוקן המקורי לא נעלם');
    });

    test('נתפסים גם טוקנים שמכילים את המילה — תוצאות נוספות', () {
      const word = 'תורה';
      final pattern = partialWordPattern(word);
      // טוקנים שהחיפוש המדויק *לא* היה תופס, ועכשיו כן:
      for (final token in ['התורה', 'כתורה', 'תורהו']) {
        expect(tokenMatches(exactPattern(word), token), isFalse,
            reason: 'חיפוש מדויק לא תופס "$token"');
        expect(tokenMatches(pattern, token), isTrue,
            reason: '"חלק ממילה" תופס גם "$token"');
      }
    });

    test('כל טוקן שהחיפוש המדויק תופס — נתפס גם עם "חלק ממילה" (על-קבוצה)', () {
      const word = 'תורה';
      final exact = exactPattern(word);
      final partial = partialWordPattern(word);
      // מדגם רחב של טוקנים; כל מה שהמדויק תופס, גם החלקי תופס.
      const corpus = [
        'תורה',
        'התורה',
        'ותורה',
        'תורתו',
        'מצוה',
        'שלום',
        'בראשית',
        'כתורהם',
      ];
      for (final token in corpus) {
        if (tokenMatches(exact, token)) {
          expect(tokenMatches(partial, token), isTrue,
              reason: 'הפרה של על-קבוצה: "$token" נתפס במדויק אך לא בחלקי');
        }
      }
    });
  });

  group('שגיאות כתיב — מרחיב, לא מגביל', () {
    test('הטוקן המקורי עדיין נתפס', () {
      const word = 'חכמה';
      expect(tokenMatches(typoPattern(word), word), isTrue,
          reason: '"שגיאות כתיב" כולל תמיד את המילה המקורית');
    });

    test('נתפסים גם טוקנים עם שגיאת כתיב — תוצאות נוספות', () {
      const word = 'חכמה';
      final pattern = typoPattern(word);
      // וריאציות במרחק עריכה 1 שהחיפוש המדויק לא תופס:
      for (final token in ['הכמה', 'חמכה']) {
        expect(tokenMatches(exactPattern(word), token), isFalse);
        expect(tokenMatches(pattern, token), isTrue,
            reason: '"שגיאות כתיב" תופס גם "$token"');
      }
    });

    test('כל טוקן שהחיפוש המדויק תופס — נתפס גם עם "שגיאות כתיב" (על-קבוצה)',
        () {
      for (final word in ['חכמה', 'רעה', 'שלום']) {
        final exact = exactPattern(word);
        final typo = typoPattern(word);
        // המילה עצמה היא הטוקן היחיד שהמדויק תופס — חייב להיתפס גם בטיפו.
        expect(tokenMatches(exact, word), isTrue);
        expect(tokenMatches(typo, word), isTrue,
            reason: 'הפרה של על-קבוצה עבור "$word"');
      }
    });
  });

  String bothPattern(String word) => SearchQueryBuilder.buildAdvancedQuery(
        [word],
        null,
        {
          SearchQueryBuilder.buildWordKey(word, 0): {
            'חלק ממילה': true,
            SearchQueryBuilder.typoToleranceOptionKey: true,
          }
        },
      ).first;

  group('שתיהן יחד — מצטברות (על-קבוצה של כל אחת לבדה)', () {
    const word = 'חכמה';

    test('הטוקן המקורי עדיין נתפס', () {
      expect(tokenMatches(bothPattern(word), word), isTrue);
    });

    test('כל מה ש"חלק ממילה" לבד תופס — נתפס גם בשתיהן', () {
      final partial = partialWordPattern(word);
      final both = bothPattern(word);
      // טוקן שמכיל את המילה המקורית
      for (final token in ['החכמה', 'חכמהו', 'חכמה']) {
        if (tokenMatches(partial, token)) {
          expect(tokenMatches(both, token), isTrue,
              reason: 'שתיהן חייבות לתפוס את "$token" שחלק-ממילה תופס');
        }
      }
    });

    test('כל מה ש"שגיאות כתיב" לבד תופס — נתפס גם בשתיהן', () {
      final typo = typoPattern(word);
      final both = bothPattern(word);
      for (final token in ['הכמה', 'חמכה', 'חכמה']) {
        if (tokenMatches(typo, token)) {
          expect(tokenMatches(both, token), isTrue,
              reason: 'שתיהן חייבות לתפוס את "$token" ששגיאות-כתיב תופס');
        }
      }
    });

    test('"משה" בשתיהן תופס את "משה" הרגיל', () {
      // מקרה קצה: מילה קצרה (3 אותיות) שמייצרת הרבה וריאציות טיפו.
      // יש לוודא שהוריאציה המקורית לא נחתכת ע"י תקרת ה-48.
      expect(tokenMatches(bothPattern('משה'), 'משה'), isTrue,
          reason: '"משה" המקורי חייב להיתפס גם כששתי האפשרויות דלוקות');
    });

    test('שתיהן תופסות גם טוקן שאף אפשרות לבדה לא תופסת', () {
      // "ההכמה" = ה + (הכמה, וריאציית טיפו של חכמה).
      // חלק-ממילה לבד מחפש את "חכמה" כתת-מחרוזת → לא קיים כאן.
      // שגיאות-כתיב לבד מעוגן לטוקן → "ההכמה" ≠ "הכמה".
      // רק השילוב — תת-מחרוזת של וריאציית טיפו — תופס.
      const token = 'ההכמה';
      expect(tokenMatches(partialWordPattern(word), token), isFalse);
      expect(tokenMatches(typoPattern(word), token), isFalse);
      expect(tokenMatches(bothPattern(word), token), isTrue,
          reason: 'השילוב מרחיב מעבר לאיחוד הפשוט של השתיים');
    });
  });

  group('השוואת ספירת התאמות מול קורפוס — הוכחת כמות', () {
    // קורפוס טוקנים מייצג. סופרים כמה טוקנים כל תבנית תופסת.
    const corpus = [
      'תורה',
      'התורה',
      'ותורה',
      'כתורה',
      'תורתו',
      'תורהו',
      'הכמה',
      'חכמה',
      'חמכה',
      'מצוה',
      'שלום',
      'בראשית',
    ];

    int countMatches(String pattern) =>
        corpus.where((t) => tokenMatches(pattern, t)).length;

    test('"חלק ממילה" תופס לפחות כמו חיפוש מדויק, ובפועל יותר', () {
      const word = 'תורה';
      final exactCount = countMatches(exactPattern(word));
      final partialCount = countMatches(partialWordPattern(word));
      expect(partialCount, greaterThanOrEqualTo(exactCount));
      expect(partialCount, greaterThan(exactCount),
          reason: 'במידע הזה "חלק ממילה" אמור להוסיף התאמות');
    });

    test('"שגיאות כתיב" תופס לפחות כמו חיפוש מדויק, ובפועל יותר', () {
      const word = 'חכמה';
      final exactCount = countMatches(exactPattern(word));
      final typoCount = countMatches(typoPattern(word));
      expect(typoCount, greaterThanOrEqualTo(exactCount));
      expect(typoCount, greaterThan(exactCount),
          reason: 'במידע הזה "שגיאות כתיב" אמור להוסיף התאמות');
    });
  });

  group('שפיות: התבנית הבסיסית באמת מצומצמת לטוקן המדויק', () {
    test('חיפוש מדויק של "תורה" לא תופס "התורה"', () {
      // מאשר שהבסיס שאנו משווים מולו הוא באמת חיפוש טוקן מדויק,
      // כך שהמסקנה "מרחיב" אינה ארטיפקט של בסיס שגוי.
      final pattern = SearchRegexPatterns.createSearchPattern('תורה');
      expect(tokenMatches(pattern, 'תורה'), isTrue);
      expect(tokenMatches(pattern, 'התורה'), isFalse);
    });
  });
}
