import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart'
    show SearchScope, WordMatchMode;

void main() {
  group('SearchMatchPolicy', () {
    test('ברירת המחדל היא מרווח מילים וכל המילים', () {
      expect(SearchMatchPolicy.standard.isStandard, isTrue);
      expect(
        SearchMatchPolicy.standard.proximityScope,
        SearchScope.wordDistance,
      );
      expect(SearchMatchPolicy.standard.wordMatchMode, WordMatchMode.all);
    });

    test('טווח קרבה שאינו מרווח מילים אינו ברירת מחדל', () {
      expect(
        const SearchMatchPolicy(
          proximityScope: SearchScope.sameSection,
        ).isStandard,
        isFalse,
      );
    });

    test('התאמה חלקית אינה ברירת מחדל', () {
      expect(
        const SearchMatchPolicy(
          wordMatchMode: WordMatchMode.mostWords,
        ).isStandard,
        isFalse,
      );
    });

    test('מספר מילים לבדו אינו הופך את המדיניות ללא-רגילה', () {
      // המונה משמעותי רק במצב "לפחות X מילים", ולכן אינו נבדק ב-isStandard.
      expect(const SearchMatchPolicy(wordMatchCount: 5).isStandard, isTrue);
    });

    test('שוויון לפי ערכים — מאפשר השוואת state בלי רענון מיותר', () {
      const first = SearchMatchPolicy(
        proximityScope: SearchScope.sameParagraph,
        wordMatchMode: WordMatchMode.atLeast,
        wordMatchCount: 3,
      );
      const second = SearchMatchPolicy(
        proximityScope: SearchScope.sameParagraph,
        wordMatchMode: WordMatchMode.atLeast,
        wordMatchCount: 3,
      );
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(const SearchMatchPolicy()));
    });

    test('SearchConfiguration.forInBookSearch נושא את המדיניות לדיאלוג', () {
      // דיאלוג החיפוש המתקדם שנפתח מתוך ספר קורא את הקונפיגורציה הזו;
      // בלי המדיניות הוא היה נפתח בברירות מחדל ומוחק אותה באישור.
      const policy = SearchMatchPolicy(
        proximityScope: SearchScope.sameSection,
        wordMatchMode: WordMatchMode.atLeast,
        wordMatchCount: 3,
      );
      final configuration = SearchConfiguration.forInBookSearch(
        searchMode: SearchMode.advanced,
        distance: 4,
        matchPolicy: policy,
      );

      expect(configuration.searchMode, SearchMode.advanced);
      expect(configuration.distance, 4);
      expect(configuration.matchPolicy, policy);
    });

    test('SearchConfiguration.matchPolicy נגזר משדות הקונפיגורציה', () {
      const configuration = SearchConfiguration(
        proximityScope: SearchScope.sameSection,
        wordMatchMode: WordMatchMode.anyWord,
        wordMatchCount: 4,
      );
      expect(
        configuration.matchPolicy,
        const SearchMatchPolicy(
          proximityScope: SearchScope.sameSection,
          wordMatchMode: WordMatchMode.anyWord,
          wordMatchCount: 4,
        ),
      );
    });
  });
}
