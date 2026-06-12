import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/repository/data_repository.dart';

/// בדיקות להתאמה הסלחנית של חיפוש ספרים בספרייה.
/// הדרישה המרכזית: הדדיות — אם א' מוצא את ב', גם ב' מוצא את א'.
void main() {
  group('bookSearchWordMatchesFuzzy - הדדיות כתיב מלא/חסר', () {
    const reciprocalPairs = [
      ('מדות', 'מידות'),
      ('קדושין', 'קידושין'),
      ('חדושי', 'חידושי'),
      ('קצור', 'קיצור'),
    ];

    for (final (haser, male) in reciprocalPairs) {
      test('$haser ↔ $male - שני הכיוונים', () {
        expect(bookSearchWordMatchesFuzzy(haser, 'משנה $male'), isTrue,
            reason: "'$haser' אמור למצוא '$male'");
        expect(bookSearchWordMatchesFuzzy(male, 'משנה $haser'), isTrue,
            reason: "'$male' אמור למצוא '$haser'");
      });
    }
  });

  group('bookSearchWordMatchesFuzzy - מניעת התאמות שווא', () {
    test('מילים קצרות באותו אורך נשארות מדויקות', () {
      expect(bookSearchWordMatchesFuzzy('מדות', 'ספר מצות'), isFalse);
      expect(bookSearchWordMatchesFuzzy('אבות', 'ספר עדות'), isFalse);
    });

    test('מילה קצרה מ-3 אותיות - רק התאמת substring, בלי fuzzy', () {
      expect(bookSearchWordMatchesFuzzy('שב', 'מסכת שבת'), isTrue);
      expect(bookSearchWordMatchesFuzzy('שג', 'מסכת שבת'), isFalse);
      expect(bookSearchWordMatchesFuzzy('שבת', 'מסכת שבות'), isFalse);
    });

    test('פער של שתי אותיות במילה קצרה אינו מותאם', () {
      expect(bookSearchWordMatchesFuzzy('מדות', 'ספר מהדורות'), isFalse);
    });

    test('התאמת substring מדויקת עדיין עובדת', () {
      expect(bookSearchWordMatchesFuzzy('קידושין', 'מאירי על קידושין'), isTrue);
    });

    test('שיכול אותיות סמוכות נספר כשגיאה אחת', () {
      expect(bookSearchWordMatchesFuzzy('אבועלפיה', 'רבי אבולעפיה'), isTrue);
    });
  });

  group('filterBookSearchEntries - התאמה דרך כינויים', () {
    const entries = [
      BookSearchEntry(
        index: 0,
        title: 'קידושין',
        author: '',
        topics: '',
        acronyms: ['מסכת קידושין', 'גמרא קידושין'],
      ),
      BookSearchEntry(
        index: 1,
        title: 'ספר המדות',
        author: '',
        topics: '',
        acronyms: ['ספר המידות'],
      ),
      BookSearchEntry(
        index: 2,
        title: 'מסילת ישרים',
        author: 'רמח"ל',
        topics: '',
      ),
    ];

    List<int> search(String query) => filterBookSearchEntries(
          entries: entries,
          queryWords: query.split(' '),
          topics: const [],
          sortByRatio: true,
          normalizedQuery: query,
        );

    test('שאילתה שתואמת רק כינוי מוצאת את הספר', () {
      expect(search('מסכת קידושין'), contains(0));
    });

    test('כינוי בכתיב אחר מהכותרת נמצא בשני הכתיבים', () {
      expect(search('ספר המידות'), contains(1));
      expect(search('ספר המדות'), contains(1));
    });

    test('התאמה סלחנית עובדת גם על כינויים', () {
      expect(search('מסכת קדושין'), contains(0));
    });

    test('התאמה מדויקת בכותרת מדורגת לפני התאמה בכינוי', () {
      const withTitleMatch = [
        ...entries,
        BookSearchEntry(
          index: 3,
          title: 'מסכת קידושין מבוארת',
          author: '',
          topics: '',
        ),
      ];
      final results = filterBookSearchEntries(
        entries: withTitleMatch,
        queryWords: 'מסכת קידושין'.split(' '),
        topics: const [],
        sortByRatio: true,
        normalizedQuery: 'מסכת קידושין',
      );
      expect(results.indexOf(3), lessThan(results.indexOf(0)));
    });

    test('ספר בלי כינויים לא מושפע', () {
      expect(search('מסילת ישרים'), equals([2]));
    });
  });
}
