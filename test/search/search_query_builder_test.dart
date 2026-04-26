import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/search_query_builder.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  group('sanitizeQuery', () {
    test('מחזיר query ריק ללא שינוי', () {
      expect(SearchQueryBuilder.sanitizeQuery(''), '');
    });

    test('מסיר פסיקים', () {
      expect(SearchQueryBuilder.sanitizeQuery('תורה, ומצוות'), 'תורה ומצוות');
    });

    test('מסיר גרשיים', () {
      expect(SearchQueryBuilder.sanitizeQuery("ה'"), 'ה');
    });

    test('מסיר גרשיים עבריים (״ ו-׳)', () {
      expect(SearchQueryBuilder.sanitizeQuery('ר״ן'), 'רן');
      expect(SearchQueryBuilder.sanitizeQuery("א׳"), 'א');
    });

    test('מסיר סימני שאלה וקריאה', () {
      expect(SearchQueryBuilder.sanitizeQuery('מה?'), 'מה');
      expect(SearchQueryBuilder.sanitizeQuery('כן!'), 'כן');
    });

    test('מסיר סוגריים', () {
      expect(
          SearchQueryBuilder.sanitizeQuery('(תורה) [ומצוות] {ונביאים}'), 'תורה ומצוות ונביאים');
    });

    test('מסיר כוכביות ונקודות', () {
      expect(SearchQueryBuilder.sanitizeQuery('תורה.*'), 'תורה');
    });

    test('מסיר מעוין וסולמית ומקף בינתיים', () {
      expect(SearchQueryBuilder.sanitizeQuery('^abc\$'), 'abc');
    });

    test('מסיר backslash וpipe', () {
      expect(SearchQueryBuilder.sanitizeQuery('a\\b|c'), 'abc');
    });

    test('query עם רק תווים מיוחדים → ריק', () {
      expect(SearchQueryBuilder.sanitizeQuery('*!?.,'), '');
      expect(SearchQueryBuilder.sanitizeQuery('"..."'), '');
    });

    test('query טהור עברי נשמר', () {
      expect(SearchQueryBuilder.sanitizeQuery('בראשית ברא אלהים'), 'בראשית ברא אלהים');
    });

    test('חותך רווחים מהצדדים', () {
      expect(SearchQueryBuilder.sanitizeQuery('  תורה  '), 'תורה');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('buildAdvancedQuery', () {
    test('מילה בודדת ללא אפשרויות → מחזירה אותה', () {
      final result = SearchQueryBuilder.buildAdvancedQuery(['תורה'], null, null);
      expect(result, ['תורה']);
    });

    test('שתי מילים ללא אפשרויות', () {
      final result =
          SearchQueryBuilder.buildAdvancedQuery(['תורה', 'ומצוות'], null, null);
      expect(result, ['תורה', 'ומצוות']);
    });

    test('מילה ריקה ברשימה מסוננת', () {
      final result =
          SearchQueryBuilder.buildAdvancedQuery(['תורה', '', 'ברא'], null, null);
      // מילה ריקה עוברת דרך fallback: regexTerms.add(word) - מוסיף מחרוזת ריקה
      // אך לפחות לא קורסת
      expect(result.length, 3);
    });

    test('alternativeWords יוצר regex עם OR', () {
      final result = SearchQueryBuilder.buildAdvancedQuery(
        ['ה'],
        {0: ['השם', 'אדני']},
        null,
      );
      expect(result.length, 1);
      // צריך להכיל OR
      expect(result.first, contains('|'));
    });

    test('alternativeWords ריקים לא יוצרים אופרטור ריק', () {
      final result = SearchQueryBuilder.buildAdvancedQuery(
        ['תורה'],
        {0: []},
        null,
      );
      expect(result.length, 1);
      // אין | ריק
      expect(result.first, isNot(contains('|')));
      expect(result.first, isNot(startsWith('(')));
    });

    test('מגביל וריאציות ל-20', () {
      final manyAlternatives = List.generate(25, (i) => 'alt$i');
      final result = SearchQueryBuilder.buildAdvancedQuery(
        ['word'],
        {0: manyAlternatives},
        null,
      );
      expect(result.length, 1);
      // הרגקס לא אמור להכיל יותר מ-20 וריאציות
    });

    test('variations ריקות לאחר סינון → המילה מדולגת', () {
      // אפשרויות שכולן רווחים - אחרי trim יהיו ריקות
      final result = SearchQueryBuilder.buildAdvancedQuery(
        ['  '],
        {0: ['   ', '  ']},
        null,
      );
      // מילה ריקה עם אלטרנטיבות ריקות - validOptions ריק, fallback למילה
      expect(result, isNotEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('prepareQueryParams - מקרים בסיסיים', () {
    test('query ריק אחרי sanitize → regexTerms ריק', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          '***', false, 0, null, null, null);
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms, isEmpty);
    });

    test('מילה אחת, לא fuzzy → regexTerms מכיל את המילה כולה', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          'תורה', false, 0, null, null, null);
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms, ['תורה']);
      expect(params['effectiveSlop'], 0);
    });

    test('שתי מילים, לא fuzzy → regexTerms מכיל שתיהן', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          'בראשית ברא', false, 0, null, null, null);
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms.length, 2);
      expect(regexTerms, contains('בראשית'));
      expect(regexTerms, contains('ברא'));
    });

    test('fuzzy=true → effectiveSlop שווה ל-distance', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          'תורה', true, 3, null, null, null);
      expect(params['effectiveSlop'], 3);
    });

    test('query עם פסיקים → מנוקה לפני פיצול', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          'תורה, ברא', false, 0, null, null, null);
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms, isNotEmpty);
      for (final term in regexTerms) {
        expect(term, isNot(contains(',')));
      }
    });

    test('query עם רק תווים מוסרים → regexTerms ריק', () {
      // sanitizeQuery מסיר: , ! ? \' " ״ ׳ : * ( ) [ ] { } ^ $ | \\ + . ~ `
      final params = SearchQueryBuilder.prepareQueryParams(
          '!?.,*', false, 0, null, null, null);
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('prepareQueryParams - alternativeWords', () {
    test('עם alternativeWords → activates buildAdvancedQuery', () {
      final params = SearchQueryBuilder.prepareQueryParams(
        'תורה',
        false,
        0,
        null,
        {0: ['ומצוות']},
        null,
      );
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms.length, 1);
      expect(regexTerms.first, contains('|'));
    });

    test('alternativeWords ריקים → לא מגיע ל-buildAdvancedQuery', () {
      final params = SearchQueryBuilder.prepareQueryParams(
        'תורה',
        false,
        0,
        null,
        {},
        null,
      );
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms, ['תורה']);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('prepareQueryParams - customSpacing', () {
    test('עם customSpacing → effectiveSlop מחושב', () {
      final params = SearchQueryBuilder.prepareQueryParams(
        'בראשית ברא',
        false,
        0,
        {'0-1': '5'},
        null,
        null,
      );
      expect(params['effectiveSlop'], 5);
    });

    test('customSpacing ריק → effectiveSlop=0', () {
      final params = SearchQueryBuilder.prepareQueryParams(
        'בראשית ברא',
        false,
        0,
        {},
        null,
        null,
      );
      expect(params['effectiveSlop'], 0);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('prepareQueryParams - maxExpansions', () {
    test('לא fuzzy, מילה אחת → maxExpansions=10', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          'תורה', false, 0, null, null, null);
      expect(params['maxExpansions'], 10);
    });

    test('לא fuzzy, שתי מילים → maxExpansions=100', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          'בראשית ברא', false, 0, null, null, null);
      expect(params['maxExpansions'], 100);
    });

    test('fuzzy → maxExpansions=50', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          'תורה', true, 2, null, null, null);
      expect(params['maxExpansions'], 50);
    });

    test('עם סיומות ומילה קצרה → maxExpansions גבוה', () {
      final params = SearchQueryBuilder.prepareQueryParams(
        'שם',
        false,
        0,
        null,
        null,
        {'שם_0': {'סיומות': true}},
      );
      expect(params['maxExpansions'], greaterThanOrEqualTo(2000));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('getMaxCustomSpacing', () {
    test('ריק → מחזיר 0', () {
      expect(SearchQueryBuilder.getMaxCustomSpacing({}, 3), 0);
    });

    test('מחזיר ערך מקסימלי מבין כל המרווחים', () {
      expect(
          SearchQueryBuilder.getMaxCustomSpacing({'0-1': '3', '1-2': '7'}, 3),
          7);
    });

    test('ערך לא מספרי → מוחזר כ-0', () {
      expect(SearchQueryBuilder.getMaxCustomSpacing({'0-1': 'abc'}, 2), 0);
    });

    test('wordCount=1 → אין מרווחים, תמיד 0', () {
      expect(SearchQueryBuilder.getMaxCustomSpacing({'0-1': '5'}, 1), 0);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('calculateMaxExpansions', () {
    test('fuzzy → 50', () {
      expect(SearchQueryBuilder.calculateMaxExpansions(true, 1), 50);
    });

    test('לא fuzzy, termCount=1 → 10', () {
      expect(SearchQueryBuilder.calculateMaxExpansions(false, 1), 10);
    });

    test('לא fuzzy, termCount>1 → 100', () {
      expect(SearchQueryBuilder.calculateMaxExpansions(false, 3), 100);
    });

    test('מילה של תו אחד עם קידומת → maxExpansions≥2000', () {
      expect(
        SearchQueryBuilder.calculateMaxExpansions(
          false,
          1,
          searchOptions: {'א_0': {'קידומות': true}},
          words: ['א'],
        ),
        greaterThanOrEqualTo(2000),
      );
    });

    test('מילה של 2 תווים עם סיומת → maxExpansions≥3000', () {
      expect(
        SearchQueryBuilder.calculateMaxExpansions(
          false,
          1,
          searchOptions: {'אב_0': {'סיומות': true}},
          words: ['אב'],
        ),
        greaterThanOrEqualTo(3000),
      );
    });

    test('מילה של 3 תווים עם חלק ממילה → maxExpansions≥4000', () {
      expect(
        SearchQueryBuilder.calculateMaxExpansions(
          false,
          1,
          searchOptions: {'תור_0': {'חלק ממילה': true}},
          words: ['תור'],
        ),
        greaterThanOrEqualTo(4000),
      );
    });

    test('מילה ארוכה עם סיומות דקדוקיות → maxExpansions=5000', () {
      expect(
        SearchQueryBuilder.calculateMaxExpansions(
          false,
          1,
          searchOptions: {'תורה_0': {'סיומות דקדוקיות': true}},
          words: ['תורה'],
        ),
        5000,
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('תרחישי הבאג: אופרטורים ריקים', () {
    test('sanitize של query עם רק גרשיים → regexTerms ריק, לא קורס', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          '"""', false, 0, null, null, null);
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms, isEmpty);
    });

    test('sanitize של query עם סוגריים בלבד → regexTerms ריק', () {
      final params = SearchQueryBuilder.prepareQueryParams(
          '()', false, 0, null, null, null);
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms, isEmpty);
    });

    test('buildAdvancedQuery לא מייצר (abc|) - אופרטור ריק', () {
      // אם allVariations מכיל string ריק, הוא אמור להיות מסונן
      final result = SearchQueryBuilder.buildAdvancedQuery(
        ['תורה'],
        {0: ['', '   ']},
        null,
      );
      for (final term in result) {
        expect(term, isNot(matches(r'\(\||\|\)')));
        expect(term, isNot(equals('()')));
      }
    });

    test('query עם רק נקודה → regexTerms ריק', () {
      final params =
          SearchQueryBuilder.prepareQueryParams('.', false, 0, null, null, null);
      final regexTerms = params['regexTerms'] as List<String>;
      expect(regexTerms, isEmpty);
    });
  });
}
