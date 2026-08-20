import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/cache/acronyms_cache.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

/// בדיקות לאינדקס הביגרמים שמצמצם את סריקת הכינויים ב"איתור מקורות".
///
/// האינווריאנטה שכל האופטימיזציה נשענת עליה: המסננת היא **קבוצת-על** — ספר
/// שיש לו כינוי המכיל את השאילתה חייב להיות בין המועמדים. אם היא נשברת,
/// ספרים ייעלמו מתוצאות האיתור.
void main() {
  /// הכינויים והמזהים הם נתוני אמת מ-`seforim.db`.
  const corpus = <int, List<String>>{
    101: ['רמב"ם', 'משנה תורה', 'יד החזקה'],
    102: ['רמב"ם הלכות תפילה', 'הלכות תפילה'],
    103: ['שו"ע או"ח', 'שולחן ערוך אורח חיים'],
    104: ['טור חושן משפט', 'טור חו"מ'],
    105: ['רש"י', 'פירוש רש"י'],
    106: ['פסקי הרא"ש', 'פסקי הראש על ברכות'],
    107: ['ב"ק', 'בבא קמא'],
    108: ['תוספות'],
  };

  tearDown(AcronymsCache.instance.clear);

  /// כל התת-מחרוזות באורך 2 ומעלה של כל הכינויים — כל שאילתה שיכולה להתאים.
  Set<String> allMatchableQueries() {
    final queries = <String>{};
    for (final terms in corpus.values) {
      for (final raw in terms) {
        final term = normalizeForFindRefMatch(raw);
        for (var start = 0; start < term.length; start++) {
          for (var end = start + 2; end <= term.length; end++) {
            queries.add(term.substring(start, end));
          }
        }
      }
    }
    return queries;
  }

  /// הספרים שהיום היו מקבלים דירוג כינוי עבור [query] — התאמה בזהות,
  /// בתחילית או בהכלה, כלומר בדיוק "מונח שמכיל את השאילתה".
  Set<int> booksMatchingByAcronym(String query) => {
    for (final entry in corpus.entries)
      if (entry.value.any(
        (raw) => normalizeForFindRefMatch(raw).contains(query),
      ))
        entry.key,
  };

  group('AcronymsCache.candidatesFor - קבוצת-על', () {
    test('כל ספר שכינויו מכיל את השאילתה נמצא בין המועמדים', () {
      AcronymsCache.instance.setAcronymsForTesting(corpus);

      final queries = allMatchableQueries();
      expect(queries.length, greaterThan(200), reason: 'כיסוי סביר של שאילתות');

      for (final query in queries) {
        final candidates = AcronymsCache.instance.candidatesFor(query);
        expect(candidates, isNotNull, reason: 'שאילתה "$query" ניתנת לאינדוקס');
        for (final bookId in booksMatchingByAcronym(query)) {
          expect(
            candidates!.contains(bookId),
            isTrue,
            reason: 'ספר $bookId חייב להיות מועמד עבור "$query"',
          );
        }
      }
    });

    test('האינווריאנטה נשמרת גם כשהספרים נזרעים בסדר יורד', () {
      // רשימות ההצבעה חייבות להיות ממוינות כדי שהחיפוש הבינארי יעבוד;
      // הבנייה ממיינת את המזהים בעצמה ואינה תלויה בסדר ההזרקה.
      AcronymsCache.instance.setAcronymsForTesting({
        for (final key in corpus.keys.toList().reversed) key: corpus[key]!,
      });

      for (final query in allMatchableQueries()) {
        final candidates = AcronymsCache.instance.candidatesFor(query)!;
        for (final bookId in booksMatchingByAcronym(query)) {
          expect(
            candidates.contains(bookId),
            isTrue,
            reason:
                'ספר $bookId חייב להיות מועמד עבור "$query" גם בהזרקה '
                'בסדר יורד — רשימות הביגרמים חייבות להיות ממוינות',
          );
        }
      }
    });

    test('שאילתה נדירה מצמצמת בפועל את מספר המועמדים', () {
      AcronymsCache.instance.setAcronymsForTesting(corpus);

      // ללא צמצום ממשי אין ערך לאינדקס — הבדיקה מגנה מפני התדרדרות שקטה
      // שבה כל השאילתות מחזירות את כל הספרים.
      expect(
        AcronymsCache.instance.candidatesFor('תוספות')!.length,
        lessThan(corpus.length),
      );
      expect(AcronymsCache.instance.candidatesFor('קמא')!.length, 1);
    });

    test('נבחרת רשימת הביגרם הנדירה, לא הנפוצה', () {
      // 'בם' משותף לכל הספרים; 'רמ' ו'מב' ייחודיים ל-201. בחירת הביגרם
      // הנפוץ הייתה נשארת קבוצת-על תקינה ומוחקת את כל השיפור בשקט.
      AcronymsCache.instance.setAcronymsForTesting({
        201: ['רמב"ם'],
        for (var id = 202; id <= 221; id++) id: ['רשב"ם'],
      });

      expect(AcronymsCache.instance.candidatesFor('רמבם')!.length, 1);
    });

    test('זריעה מחדש: ספר שנעלם אינו מועמד, וספר חדש כן', () {
      AcronymsCache.instance.setAcronymsForTesting({
        101: ['רמב"ם'],
        102: ['תוספות'],
      });
      expect(AcronymsCache.instance.candidatesFor('רמבם')!.contains(101), true);

      AcronymsCache.instance.setAcronymsForTesting({
        102: ['תוספות'],
        103: ['שולחן ערוך'],
      });

      expect(
        AcronymsCache.instance.candidatesFor('רמבם')!.contains(101),
        false,
      );
      expect(
        AcronymsCache.instance.candidatesFor('שולחן')!.contains(103),
        true,
      );
    });
  });

  group('AcronymsCache.candidatesFor - מקרי קצה', () {
    test('שאילתה קצרה מ-2 תווים אינה ניתנת לאינדוקס — סריקה מלאה', () {
      AcronymsCache.instance.setAcronymsForTesting(corpus);

      expect(AcronymsCache.instance.candidatesFor('ב'), isNull);
      expect(AcronymsCache.instance.candidatesFor(''), isNull);
    });

    test('ביגרם שאינו במאגר מחזיר קבוצת מועמדים ריקה', () {
      AcronymsCache.instance.setAcronymsForTesting(corpus);

      final candidates = AcronymsCache.instance.candidatesFor('זזזז');
      expect(candidates, isNotNull);
      expect(candidates!.length, 0);
      for (final bookId in corpus.keys) {
        expect(candidates.contains(bookId), isFalse);
      }
    });

    test('אינדקס ריק מול מונחים קיימים מחזיר null — סריקה מלאה', () {
      // מונחים בני תו אחד אינם מייצרים ביגרם. השסתום הזה הוא מה שמונע
      // היעלמות שקטה של כל התאמת הכינויים.
      AcronymsCache.instance.setAcronymsForTesting({
        101: ['א'],
        102: ['ב'],
      });

      expect(AcronymsCache.instance.getAcronymsForBook(101), isNotEmpty);
      expect(AcronymsCache.instance.candidatesFor('אב'), isNull);
    });

    test('קאש שלא נטען מחזיר null ולא קבוצה ריקה', () {
      // null = "סרוק את כל הספרים". קבוצה ריקה כאן הייתה מבטלת כל התאמת
      // כינויים עד לחימום הקאש.
      expect(AcronymsCache.instance.candidatesFor('רמבם'), isNull);
    });

    test('clear מאפס גם את האינדקס', () {
      AcronymsCache.instance.setAcronymsForTesting(corpus);
      expect(AcronymsCache.instance.candidatesFor('רמבם'), isNotNull);

      AcronymsCache.instance.clear();

      expect(AcronymsCache.instance.candidatesFor('רמבם'), isNull);
    });

    test('ספר בלי כינויים אינו מועמד לאף שאילתה', () {
      AcronymsCache.instance.setAcronymsForTesting({
        ...corpus,
        999: const <String>[],
      });

      for (final query in ['רמבם', 'תוספות', 'קמא']) {
        expect(
          AcronymsCache.instance.candidatesFor(query)!.contains(999),
          isFalse,
        );
      }
    });
  });
}
