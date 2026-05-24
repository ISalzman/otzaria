import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';

class MockDataRepository extends Mock implements DataRepository {}

/// מסנן TOC בצורה היררכית — מדמה את הלוגיקה של [SeforimRepository._searchTocHierarchically].
/// משמש את המוק ב-buildRepo כדי שיחזיר תוצאות מסוננות כמו ב-production.
List<Map<String, dynamic>> _filterTocHierarchically(
  List<Map<String, dynamic>> entries,
  List<String> queryTokens,
  String bookTitle,
) {
  if (entries.isEmpty || queryTokens.isEmpty) return entries;

  // מחשב את הטקסט העצמי של כל ערך (ללא הורים)
  List<String> ownTokensOf(Map<String, dynamic> entry) {
    final ref = entry['reference'] as String;
    final level = entry['level'] as int;
    String ownPart;
    if (level <= 1) {
      ownPart =
          ref.startsWith('$bookTitle ') ? ref.substring(bookTitle.length + 1) : ref;
    } else {
      final parent = entries.firstWhere(
        (e) =>
            (e['level'] as int) == level - 1 &&
            ref.startsWith('${e['reference'] as String} '),
        orElse: () => <String, dynamic>{'reference': bookTitle, 'level': 0},
      );
      final parentRef = parent['reference'] as String;
      ownPart = ref.startsWith('$parentRef ')
          ? ref.substring(parentRef.length + 1)
          : ref;
    }
    return ownPart.split(' ').where((t) => t.isNotEmpty).toList();
  }

  // כל הצאצאים (רקורסיבי)
  List<Map<String, dynamic>> allDescendants(List<Map<String, dynamic>> parents) {
    final result = <Map<String, dynamic>>[];
    for (final parent in parents) {
      final parentRef = parent['reference'] as String;
      final parentLevel = parent['level'] as int;
      final children = entries.where((e) {
        final eRef = e['reference'] as String;
        final eLevel = e['level'] as int;
        return eLevel == parentLevel + 1 && eRef.startsWith('$parentRef ');
      }).toList();
      result.addAll(children);
      result.addAll(allDescendants(children));
    }
    return result;
  }

  // מחזיר את הטוקן + טרנספוזיציה (כמו _hebrewTokenAlternatives ב-seforim_repository)
  List<String> alts(String token) {
    if (token.length == 2) {
      final c0 = token.codeUnitAt(0);
      final c1 = token.codeUnitAt(1);
      if (c0 >= 0x05D0 && c0 <= 0x05EA && c1 >= 0x05D0 && c1 <= 0x05EA && c0 != c1) {
        return [token, '${token[1]}${token[0]}'];
      }
    }
    return [token];
  }

  var searchScope =
      entries.where((e) => (e['level'] as int) == 1).toList();
  var currentMatches = <Map<String, dynamic>>[];

  for (final token in queryTokens) {
    final tokenAlts = alts(token);
    final found = searchScope
        .where((e) => tokenAlts.any((alt) => ownTokensOf(e).contains(alt)))
        .toList();
    if (found.isEmpty) break;

    var minLevel = found.fold(
        (found.first['level'] as int), (m, e) => (e['level'] as int) < m ? (e['level'] as int) : m);
    currentMatches =
        found.where((e) => (e['level'] as int) == minLevel).toList();

    final children = currentMatches.expand((m) {
      final mRef = m['reference'] as String;
      final mLevel = m['level'] as int;
      return entries.where((e) {
        final eRef = e['reference'] as String;
        final eLevel = e['level'] as int;
        return eLevel == mLevel + 1 && eRef.startsWith('$mRef ');
      });
    }).toList();

    if (children.isNotEmpty) {
      final includeCurrentLevel = currentMatches.length > 1;
      searchScope = [
        if (includeCurrentLevel) ...currentMatches,
        ...children,
        ...allDescendants(children),
      ];
    } else {
      searchScope = currentMatches;
    }
  }

  return currentMatches;
}

/// בונה [ReferenceBookHit] עם defaults הגיוניים לקיצור הבדיקות.
ReferenceBookHit _hit({
  required int bookId,
  required String title,
  String? normalizedTitle,
  int matchRank = 0,
  String? matchedTerm,
  double orderIndex = 0.0,
  String fileType = 'txt',
  String filePath = '',
}) =>
    ReferenceBookHit(
      bookId: bookId,
      title: title,
      normalizedTitle: normalizedTitle ?? title,
      filePath: filePath,
      fileType: fileType,
      matchRank: matchRank,
      matchedTerm: matchedTerm,
      orderIndex: orderIndex,
    );

void main() {
  test('FindRef: acronym + suffix token searches TOC without the acronym token',
      () async {
    final tocQueryTokensSeen = <List<String>?>[];

    final repository = FindRefRepository(
      dataRepository: MockDataRepository(),
      isReferenceBooksCacheLoaded: () => true,
      warmUpReferenceBooksCache: () async {},
      searchReferenceBooks: (query, {int limit = 50}) {
        if (query == 'משנב') {
          return [
            ReferenceBookHit(
              bookId: 1,
              title: 'משנה ברורה',
              normalizedTitle: 'משנה ברורה',
              filePath: '',
              fileType: 'txt',
              matchRank: 3, // acronym match
              matchedTerm: 'משנב',
              orderIndex: 0.0,
            ),
          ];
        }

        // Ensure second-word match doesn't short-circuit TOC.
        return const <ReferenceBookHit>[];
      },
      getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
        tocQueryTokensSeen.add(queryTokens);

        // Regression: for "משנב ב" we expect TOC queryTokens == ['ב']
        if (bookId == 1 &&
            bookTitle == 'משנה ברורה' &&
            listEquals(queryTokens, const ['ב'])) {
          return [
            {
              'reference': 'משנה ברורה סימן ב',
              'segment': 10,
              'level': 2,
            },
          ];
        }

        return const <Map<String, dynamic>>[];
      },
    );

    final results = await repository.findRefs('משנב ב');

    expect(
      tocQueryTokensSeen.any((t) => listEquals(t, const ['ב'])),
      isTrue,
      reason: 'TOC query should only include the suffix token',
    );
    expect(
      tocQueryTokensSeen.any((t) => (t ?? const []).contains('משנב')),
      isFalse,
      reason: 'Acronym token must not be sent to TOC filtering',
    );

    expect(results.map((r) => r.reference), contains('משנה ברורה סימן ב'));
  });

  test('FindRef: multi-word acronym ("שוע אוח") is matched as a phrase',
      () async {
    final tocQueryTokensSeen = <List<String>?>[];

    final repository = FindRefRepository(
      dataRepository: MockDataRepository(),
      isReferenceBooksCacheLoaded: () => true,
      warmUpReferenceBooksCache: () async {},
      searchReferenceBooks: (query, {int limit = 50}) {
        // Only the full phrase exists as an acronym in book_acronym.
        if (query == 'שוע אוח') {
          return [
            ReferenceBookHit(
              bookId: 2,
              title: 'שולחן ערוך אורח חיים',
              normalizedTitle: 'שולחן ערוך אורח חיים',
              filePath: '',
              fileType: 'txt',
              matchRank: 3, // acronym match
              matchedTerm: 'שוע אוח',
              orderIndex: 0.0,
            ),
          ];
        }
        return const <ReferenceBookHit>[];
      },
      getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
        tocQueryTokensSeen.add(queryTokens);

        if (bookId == 2 &&
            bookTitle == 'שולחן ערוך אורח חיים' &&
            listEquals(queryTokens, const ['יב'])) {
          return [
            {
              'reference': 'שולחן ערוך אורח חיים סימן יב',
              'segment': 12,
              'level': 2,
            },
          ];
        }

        return const <Map<String, dynamic>>[];
      },
    );

    final results = await repository.findRefs('שוע אוח יב');

    expect(
      tocQueryTokensSeen.any((t) => listEquals(t, const ['יב'])),
      isTrue,
      reason: 'TOC query should include only the suffix token',
    );
    expect(results.map((r) => r.reference),
        contains('שולחן ערוך אורח חיים סימן יב'));
  });

  test(
      'FindRef: "בראשית א" finds Genesis – not commentary books that contain "בראשית א" mid-title',
      () async {
    // Regression: "זוהר חי - בראשית א" contains "בראשית א" but the second
    // token of its *title* is not "א" – it should be ignored for phrase=2.
    // The single-token fallback should then find "בראשית" (Genesis) instead.

    final repository = FindRefRepository(
      dataRepository: MockDataRepository(),
      isReferenceBooksCacheLoaded: () => true,
      warmUpReferenceBooksCache: () async {},
      searchReferenceBooks: (query, {int limit = 50}) {
        if (query == 'בראשית') {
          return [
            ReferenceBookHit(
              bookId: 1,
              title: 'בראשית',
              normalizedTitle: 'בראשית',
              filePath: '',
              fileType: 'txt',
              matchRank: 0, // exact
              orderIndex: 1.0,
            ),
          ];
        }
        if (query == 'בראשית א') {
          // Commentary books: "בראשית" is token 0 but "א" is NOT token 1 in their title.
          return [
            ReferenceBookHit(
              bookId: 99,
              title: 'זוהר חי בראשית א',
              normalizedTitle: 'זוהר חי בראשית א',
              filePath: '',
              fileType: 'txt',
              matchRank: 2, // contains-only
              orderIndex: 99.0,
            ),
          ];
        }
        return const <ReferenceBookHit>[];
      },
      getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
        if (bookId == 1) {
          return [
            {'reference': 'בראשית פרק א', 'segment': 10, 'level': 3},
          ];
        }
        return const <Map<String, dynamic>>[];
      },
    );

    final results = await repository.findRefs('בראשית א');

    expect(results.map((r) => r.title), contains('בראשית'),
        reason: 'Genesis must appear');
    expect(results.map((r) => r.title), isNot(contains('זוהר חי בראשית א')),
        reason: 'Commentary with mid-title match must not appear');
  });

  test(
      'FindRef: "בראשית א" finds a book whose second title-token starts with "א"',
      () async {
    // A book titled "בראשית אמר" starts with "בראשית" and its second token
    // "אמר" starts with "א" → the 2-token phrase query should select it.

    final repository = FindRefRepository(
      dataRepository: MockDataRepository(),
      isReferenceBooksCacheLoaded: () => true,
      warmUpReferenceBooksCache: () async {},
      searchReferenceBooks: (query, {int limit = 50}) {
        if (query == 'בראשית א') {
          return [
            ReferenceBookHit(
              bookId: 10,
              title: 'בראשית אמר',
              normalizedTitle: 'בראשית אמר',
              filePath: '',
              fileType: 'txt',
              matchRank: 1, // startsWith "בראשית א"
              orderIndex: 5.0,
            ),
          ];
        }
        return const <ReferenceBookHit>[];
      },
      getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
        if (bookId == 10) {
          return [
            {'reference': 'בראשית אמר פסוק א', 'segment': 10, 'level': 2},
          ];
        }
        return const <Map<String, dynamic>>[];
      },
    );

    final results = await repository.findRefs('בראשית א');

    // "בראשית א" matches phrase "בראשית א" → should find "בראשית אמר" book
    expect(results.map((r) => r.title), contains('בראשית אמר'),
        reason: 'Book whose second token starts with the query token must appear');
  });

  // ─── ספרי יסוד (foundational tier) ─────────────────────────────────────────

  group('FindRef.classifyFoundationalTier — סיווג ספרי יסוד', () {
    // ה-categoryPath שמוזן ל-classifier הוא הפלט המדויק של
    // `BookDatabaseResolver.buildCategoryPath` — כלומר נתיב הקטגוריות מהשורש
    // ועד ולא כולל הספר עצמו.
    //
    // דוגמאות מ-seforim.db בפרודקשן:
    //   book "בראשית"           → cat 2="תורה"    → cat 1="תנ"ך"    → path = "תנ"ך, תורה"           (אורך 2)
    //   book "משנה שבת"         → cat 7="סדר מועד" → cat 5="משנה"    → path = "משנה, סדר מועד"       (אורך 2)
    //   book "שבת" (בבלי)       → cat 14="סדר מועד" → cat 12="תלמוד בבלי" → path = "תלמוד בבלי, סדר מועד" (אורך 2)
    //   book "משנה תורה, ה' שבת" → cat 48="ספר זמנים" → cat 44="משנה תורה" → cat 43="הלכה"
    //                                                                    → path = "הלכה, משנה תורה, ספר זמנים" (אורך 3)
    //
    // הכותרות והנתיבים בטסטים האלו תואמים בדיוק את מה שמיוצר בעת ריצה.

    test('תנ"ך: תורה/נביאים/כתובים → tier 1', () {
      expect(FindRefRepository.classifyFoundationalTier('תנ"ך, תורה', 'בראשית'),
          1);
      expect(FindRefRepository.classifyFoundationalTier('תנ"ך, נביאים', 'יהושע'),
          1);
      expect(
          FindRefRepository.classifyFoundationalTier('תנ"ך, כתובים', 'תהילים'),
          1);
    });

    test('תנ"ך עם תת-קטגוריה של מפרשים → null', () {
      // "תנ"ך, ראשונים, רש"י, תורה" — פירוש רש"י, לא ספר יסוד.
      expect(
        FindRefRepository.classifyFoundationalTier(
            'תנ"ך, ראשונים, רש"י, תורה', 'רש"י על בראשית'),
        isNull,
      );
    });

    test('משנה: "סדר X" → tier 2', () {
      expect(
          FindRefRepository.classifyFoundationalTier('משנה, סדר מועד', 'משנה שבת'),
          2);
      expect(
          FindRefRepository.classifyFoundationalTier(
              'משנה, סדר זרעים', 'משנה ברכות'),
          2);
    });

    test('משנה עם פירוש (ברטנורא, תוספות יו"ט) → null', () {
      // "משנה, ראשונים, ברטנורא, סדר מועד" — פירוש על המשנה, לא יסוד.
      expect(
        FindRefRepository.classifyFoundationalTier(
            'משנה, ראשונים, ברטנורא, סדר מועד', 'ברטנורא על משנה שבת'),
        isNull,
      );
      expect(
        FindRefRepository.classifyFoundationalTier(
            'משנה, אחרונים, תוספות יום טוב, סדר מועד', 'תוספות יום טוב על משנה שבת'),
        isNull,
      );
    });

    test('תלמוד בבלי: "סדר X" → tier 3', () {
      expect(
          FindRefRepository.classifyFoundationalTier(
              'תלמוד בבלי, סדר מועד', 'שבת'),
          3);
    });

    test('תלמוד בבלי עם פירוש (רש"י, תוספות) → null', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'תלמוד בבלי, ראשונים, רש"י, סדר מועד', 'רש"י על שבת'),
        isNull,
      );
    });

    test('תלמוד ירושלמי → tier 4', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'תלמוד ירושלמי, סדר מועד', 'ירושלמי שבת'),
        4,
      );
    });

    test('תלמוד ירושלמי עם פירוש → null', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'תלמוד ירושלמי, מפרשים, פני משה, סדר מועד', 'פני משה על ירושלמי שבת'),
        isNull,
      );
    });

    test('מדרשי הלכה: tier 5', () {
      expect(FindRefRepository.classifyFoundationalTier('מדרש, הלכה', 'ספרא'),
          5);
      expect(
          FindRefRepository.classifyFoundationalTier(
              'מדרש, הלכה', 'מכילתא דרבי ישמעאל'),
          5);
    });

    test('מדרשי אגדה: tier 6', () {
      expect(
        FindRefRepository.classifyFoundationalTier('מדרש, אגדה', 'מדרש תנחומא'),
        6,
      );
    });

    test('מדרש עם פירוש בכותרת → null', () {
      // "הערות בובר על מדרש משלי" — title-based filter כי הוא יושב באותה
      // קטגוריה ("מדרש, אגדה") כמו ספרי היסוד.
      expect(
        FindRefRepository.classifyFoundationalTier(
            'מדרש, אגדה', 'הערות בובר על מדרש משלי'),
        isNull,
      );
      expect(
        FindRefRepository.classifyFoundationalTier(
            'מדרש, הלכה', 'הערות שוליים על מכילתא דרבי שמעון בן יוחאי'),
        isNull,
      );
    });

    test('זוהר: ספרי היסוד → tier 7', () {
      expect(
          FindRefRepository.classifyFoundationalTier('קבלה, זהר', 'ספר הזהר'),
          7);
      expect(
          FindRefRepository.classifyFoundationalTier('קבלה, זהר', 'תקוני הזהר'),
          7);
      expect(
          FindRefRepository.classifyFoundationalTier('קבלה, זהר', 'זוהר חדש'),
          7);
    });

    test('זוהר עם פירוש → null (כותרת לא ברשימה)', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'קבלה, זהר', 'הסולם על ספר הזהר'),
        isNull,
      );
      expect(
        FindRefRepository.classifyFoundationalTier('קבלה, זהר', 'יהל אור על ספר הזהר'),
        isNull,
      );
    });

    test('רמב"ם (משנה תורה): "ספר X" → tier 8', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'הלכה, משנה תורה, ספר זמנים', 'משנה תורה, הלכות שבת'),
        8,
      );
      expect(
        FindRefRepository.classifyFoundationalTier(
            'הלכה, משנה תורה, הקדמה', 'הקדמת הרמב"ם'),
        8,
      );
    });

    test('רמב"ם עם פירוש (מפרשים, ראשונים) → null', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'הלכה, משנה תורה, מפרשים, אבן האזל', 'אבן האזל על משנה תורה'),
        isNull,
      );
    });

    test('טור (בלי הסתעפויות) → tier 9', () {
      expect(FindRefRepository.classifyFoundationalTier('הלכה, טור', 'טור'), 9);
    });

    test('טור עם מפרשים → null', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'הלכה, טור, מפרשים', 'כפי אהרן על טור'),
        isNull,
      );
    });

    test('שולחן ערוך → tier 10', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'הלכה, שולחן ערוך', 'שולחן ערוך, אורח חיים'),
        10,
      );
    });

    test('שולחן ערוך הרב (קטגוריה נפרדת) → null (לא תיקני "שו"ע")', () {
      // "שולחן ערוך הרב" יושב תחת קטגוריה נפרדת, לא תחת "שולחן ערוך" עצמו.
      // הוא לא נכלל ב-tier 10.
      expect(
        FindRefRepository.classifyFoundationalTier(
            'הלכה, שולחן ערוך הרב', 'שולחן ערוך הרב'),
        isNull,
      );
    });

    test('שו"ע עם מפרשים (בית מאיר, מגן אברהם) → null', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'הלכה, שולחן ערוך, מפרשים', 'בית מאיר על שולחן ערוך'),
        isNull,
      );
    });

    test('categoryPath ריק / null → null', () {
      expect(FindRefRepository.classifyFoundationalTier(null, 'בראשית'), isNull);
      expect(FindRefRepository.classifyFoundationalTier('', 'בראשית'), isNull);
    });

    test('קטגוריה לא יסודית (חסידות, שו"ת, וכו\') → null', () {
      expect(
        FindRefRepository.classifyFoundationalTier(
            'חסידות, ספר אחר', 'ספר חסידות כלשהו'),
        isNull,
      );
      expect(
        FindRefRepository.classifyFoundationalTier('שו"ת', 'שו"ת כלשהו'),
        isNull,
      );
    });
  });

  // ─── קלט שולי ───────────────────────────────────────────────────────────────

  group('FindRef — קלט שולי', () {
    test('מחרוזת ריקה מחזירה רשימה ריקה ללא קריאה למאגר', () async {
      var searchCalled = false;
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          searchCalled = true;
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      expect(await repo.findRefs(''), isEmpty);
      expect(searchCalled, isFalse,
          reason: 'Empty input must short-circuit before any cache lookup');
    });

    test('רווחים בלבד מחזירים רשימה ריקה', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {int limit = 50}) =>
            const <ReferenceBookHit>[],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      expect(await repo.findRefs('   '), isEmpty);
      expect(await repo.findRefs('\t\n'), isEmpty);
    });

    test('קלט המתנרמל לריק (סימני פיסוק בלבד) מחזיר ריק', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {int limit = 50}) =>
            const <ReferenceBookHit>[],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      // "..." → "" אחרי נורמליזציה → אסור להגיע ל-search
      expect(await repo.findRefs('...'), isEmpty);
    });
  });

  // ─── שאילתת מילה בודדת ──────────────────────────────────────────────────────

  group('FindRef — מילה בודדת', () {
    test('מילה בודדת לעולם לא מפעילה חיפוש TOC', () async {
      var tocCalls = 0;
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'בראשית') {
            return [_hit(bookId: 1, title: 'בראשית', orderIndex: 1.0)];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
          tocCalls++;
          return const <Map<String, dynamic>>[];
        },
      );

      final results = await repo.findRefs('בראשית');

      expect(tocCalls, equals(0),
          reason: 'מילה בודדת חייבת לעקוף את שלב ה-TOC');
      expect(results, hasLength(1));
      expect(results.single.reference, equals('בראשית'));
      expect(results.single.segment, equals(0));
    });

    test('מילה בודדת מוגבלת ל-15 תוצאות', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'פירוש') {
            return List.generate(
              25,
              (i) => _hit(
                bookId: 100 + i,
                title: 'פירוש ספר $i',
                matchRank: 1,
                orderIndex: i.toDouble(),
              ),
            );
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      final results = await repo.findRefs('פירוש');
      expect(results, hasLength(15),
          reason: 'התוצאות חתוכות ל-15 גם כשיש יותר ספרים');
    });
  });

  // ─── הגנת hasExactNextTokenMatch ────────────────────────────────────────────

  group('FindRef — hasExactNextTokenMatch', () {
    test(
        'כשטוקן הבא הוא ספר עצמאי מדויק — TOC לא נשלף עבור הספר החיצוני',
        () async {
      // תרחיש: query "תורה אור" → "תורה" הוא ספר, "אור" גם ספר עצמאי (rank=0).
      // הציפייה: TOC של "תורה" לא מסונן לפי "אור" כדי שלא ניצור פסוקים מזויפים.
      var tocCalled = false;

      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'תורה אור') {
            return const <ReferenceBookHit>[]; // אין ספר בשם זה במלואו
          }
          if (query == 'תורה') {
            return [_hit(bookId: 1, title: 'תורה', orderIndex: 1.0)];
          }
          if (query == 'אור') {
            // טוקן הבא מתאים בדיוק לספר אחר → matchRank=0
            return [_hit(bookId: 2, title: 'אור', matchRank: 0, orderIndex: 2.0)];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
          if (queryTokens != null && queryTokens.isNotEmpty) {
            tocCalled = true;
          }
          return const <Map<String, dynamic>>[];
        },
      );

      await repo.findRefs('תורה אור');

      expect(tocCalled, isFalse,
          reason:
              'כשהטוקן הבא הוא ספר מדויק, יש לדלג על חיפוש TOC מסונן');
    });
  });

  // ─── שאריות-ריקות → ספר + רמה 2 ─────────────────────────────────────────────

  group('FindRef — remainingTokens ריק מחזיר ספר + רמה 2', () {
    test(
        'שאילתה רב-מילים שתואמת לכותרת לחלוטין מחזירה את הספר ואת כל ערכי רמה 2',
        () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'תורה אור') {
            return [
              _hit(
                bookId: 1,
                title: 'תורה אור',
                normalizedTitle: 'תורה אור',
                matchRank: 0,
                orderIndex: 1.0,
              )
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
          // כשאין queryTokens — מחזירים TOC מלא ובוחרים רמה 2 בלבד.
          expect(queryTokens, isNull,
              reason: 'remainingTokens ריק → אסור להעביר queryTokens');
          return [
            {'reference': 'תורה אור', 'segment': 0, 'level': 0},
            {'reference': 'תורה אור פתיחה', 'segment': 1, 'level': 1},
            {'reference': 'תורה אור פרשת בראשית', 'segment': 10, 'level': 2},
            {'reference': 'תורה אור פרשת נח', 'segment': 50, 'level': 2},
          ];
        },
      );

      final results = await repo.findRefs('תורה אור');
      final refs = results.map((r) => r.reference).toList();

      expect(refs, contains('תורה אור'),
          reason: 'הספר עצמו תמיד מופיע ראשון');
      expect(refs, contains('תורה אור פרשת בראשית'));
      expect(refs, contains('תורה אור פרשת נח'));
      expect(refs.contains('תורה אור פתיחה'), isFalse,
          reason: 'רמה 1 לא מוחזרת כשאין שאריות לסנן');
    });
  });

  // ─── דירוג ──────────────────────────────────────────────────────────────────

  group('FindRef — דירוג תוצאות', () {
    test('כותרת זהה לשאילתה קודמת לכותרת שמתחילה ב-', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'מגילה') {
            return [
              _hit(
                bookId: 2,
                title: 'מגילת רות',
                matchRank: 1,
                orderIndex: 2.0,
              ),
              _hit(
                bookId: 1,
                title: 'מגילה',
                matchRank: 0,
                orderIndex: 1.0,
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      final results = await repo.findRefs('מגילה');

      expect(results.first.title, equals('מגילה'),
          reason: 'התאמת כותרת מדויקת ניצחה');
    });

    test('reference קצר יותר מועדף בשובר-תיקו', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'אבות') {
            return [_hit(bookId: 1, title: 'אבות', orderIndex: 1.0)];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
          if (queryTokens == null) {
            return [
              {
                'reference': 'אבות פרק חמישי בעניין דברים',
                'segment': 5,
                'level': 2
              },
              {'reference': 'אבות פרק א', 'segment': 1, 'level': 2},
            ];
          }
          return const <Map<String, dynamic>>[];
        },
      );

      // קלט מילה-אחת לא חודר ל-TOC — אז זה לא מצב טוב. נחליף את הזרימה:
      // נשתמש בשאילתה רב-מילים שתואמת בדיוק לספר → remainingTokens=[] → TOC רמה 2.
      // נריץ אבחנה נפרדת:
      final repo2 = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'פרקי אבות') {
            return [
              _hit(
                bookId: 1,
                title: 'פרקי אבות',
                normalizedTitle: 'פרקי אבות',
                matchRank: 0,
                orderIndex: 1.0,
              )
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (bookId, bookTitle, {queryTokens}) async {
          return [
            {
              'reference': 'פרקי אבות פרק חמישי בעניין דברים',
              'segment': 5,
              'level': 2
            },
            {'reference': 'פרקי אבות פרק א', 'segment': 1, 'level': 2},
          ];
        },
      );

      // עוטף את ה-results כדי לאמת שהקצר קודם.
      final results = await repo2.findRefs('פרקי אבות');
      final byRef = results.map((r) => r.reference).toList();

      // הספר עצמו ראשון; אחר כך פרקים — הקצר לפני הארוך.
      final idxShort = byRef.indexOf('פרקי אבות פרק א');
      final idxLong = byRef.indexOf('פרקי אבות פרק חמישי בעניין דברים');
      expect(idxShort, isNonNegative);
      expect(idxLong, isNonNegative);
      expect(idxShort, lessThan(idxLong),
          reason: 'reference קצר יותר מופיע לפני ארוך');

      // נשתמש ב-repo כדי לא להשאיר משתנה לא בשימוש.
      expect(repo, isNotNull);
    });
  });

  // ─── סולם הביטויים 3→2→1 ────────────────────────────────────────────────────

  group('FindRef — סולם ביטויים (3→2→1 טוקנים)', () {
    test('כש-3 טוקנים לא תופסים, נופלים ל-2 טוקנים', () async {
      var seenQueries = <String>[];

      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          seenQueries.add(query);
          if (query == 'שולחן ערוך אורח') {
            return const <ReferenceBookHit>[]; // 3-טוקן נכשל
          }
          if (query == 'שולחן ערוך') {
            return [
              _hit(
                bookId: 1,
                title: 'שולחן ערוך',
                normalizedTitle: 'שולחן ערוך',
                matchRank: 0,
                orderIndex: 1.0,
              )
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      await repo.findRefs('שולחן ערוך אורח');

      expect(seenQueries.first, equals('שולחן ערוך אורח'),
          reason: 'הניסיון הראשון הוא 3-טוקן');
      expect(seenQueries, contains('שולחן ערוך'),
          reason: 'נופלים ל-2 טוקן כשה-3-טוקן ריק');
    });

    test(
        'כש-2 טוקנים גם נכשלים, נופלים ל-1 טוקן',
        () async {
      var seenQueries = <String>[];

      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          seenQueries.add(query);
          if (query == 'בראשית רבה' || query == 'בראשית רבה א') {
            return const <ReferenceBookHit>[];
          }
          if (query == 'בראשית') {
            return [_hit(bookId: 1, title: 'בראשית', orderIndex: 1.0)];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      await repo.findRefs('בראשית רבה א');

      expect(seenQueries, containsAllInOrder(['בראשית רבה א', 'בראשית רבה', 'בראשית']),
          reason: 'הסולם פונה מ-3 ל-2 ל-1');
    });
  });

  // ─── דירוג עם הרבה תוצאות (decorate-sort-undecorate) ───────────────────────

  group('FindRef — דירוג עם הרבה תוצאות', () {
    test('ערבוב של exact + startsWith + tiebreaker — סדר נשמר', () async {
      // 5 ספרים שתואמים לשאילתה "רש"י", במצבי matchRank שונים.
      // הסדר הצפוי:
      // 1. כותרת זהה לחלוטין ("רשי") — exact
      // 2. כותרות שמתחילות ב-"רשי" — ממוינות לפי אורך reference (קצר→ארוך)
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'רשי') {
            return [
              _hit(
                bookId: 3,
                title: 'רשי על שמות',
                normalizedTitle: 'רשי על שמות',
                matchRank: 1,
                orderIndex: 5.0, // שווה ל"רשי על התורה" — אורך reference מכריע
              ),
              _hit(
                bookId: 1,
                title: 'רשי',
                normalizedTitle: 'רשי',
                matchRank: 0,
                orderIndex: 1.0,
              ),
              _hit(
                bookId: 2,
                title: 'רשי על התורה',
                normalizedTitle: 'רשי על התורה',
                matchRank: 1,
                orderIndex: 5.0, // שווה ל"רשי על שמות" — אורך reference מכריע
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      final results = await repo.findRefs('רשי');
      final titles = results.map((r) => r.title).toList();

      expect(titles.first, equals('רשי'),
          reason: 'התאמת כותרת מדויקת חייבת להיות ראשונה');
      // בין שאר ההתאמות (שתיהן startsWith) — הקצר יותר קודם.
      final idxShort = titles.indexOf('רשי על שמות');
      final idxLong = titles.indexOf('רשי על התורה');
      expect(idxShort, isNonNegative);
      expect(idxLong, isNonNegative);
      expect(idxShort, lessThan(idxLong),
          reason: 'reference קצר יותר קודם בשובר-תיקו');
    });

    test('שאילתה רב-מילים — דירוג לפי מיקום הטוקן השני', () async {
      // בשאילתה "רשי בראשית", שני ספרים תואמים — אחד שהטוקן 2 שלו מתחיל
      // ב-"בראשית", אחר שלא. הראשון אמור להיות לפני השני.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'רשי בראשית') {
            return [
              _hit(
                bookId: 2,
                title: 'רשי על שמות',
                normalizedTitle: 'רשי על שמות',
                matchRank: 1,
                orderIndex: 2.0,
              ),
              _hit(
                bookId: 1,
                title: 'רשי בראשית',
                normalizedTitle: 'רשי בראשית',
                matchRank: 1,
                orderIndex: 1.0,
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      final results = await repo.findRefs('רשי בראשית');
      final titles = results.map((r) => r.title).toList();

      expect(titles.first, equals('רשי בראשית'),
          reason: 'הטוקן השני של "רשי בראשית" תואם לשאילתה — קודם');
    });
  });

  // ─── חיפוש היררכי + טרנספוזיציה ────────────────────────────────────────────

  group('FindRef — חיפוש היררכי (שבת עא ב / מב יב ג / מב יב סק ג)', () {
    // ── תמצת TOC לגמרא: דף + עמוד ──────────────────────────────────────────

    List<Map<String, dynamic>> tractateToC(String bookTitle) => [
          // דף לט — שני עמודים
          {'reference': '$bookTitle דף לט', 'segment': 390, 'level': 1},
          {'reference': '$bookTitle דף לט עמוד א', 'segment': 390, 'level': 2},
          {'reference': '$bookTitle דף לט עמוד ב', 'segment': 395, 'level': 2},
          // דף עא — שני עמודים
          {'reference': '$bookTitle דף עא', 'segment': 710, 'level': 1},
          {'reference': '$bookTitle דף עא עמוד א', 'segment': 710, 'level': 2},
          {'reference': '$bookTitle דף עא עמוד ב', 'segment': 715, 'level': 2},
        ];

    // ── תמצת TOC לשו"ע: סימן → סעיף → ס"ק ─────────────────────────────────

    List<Map<String, dynamic>> shulchanToC(String bookTitle) => [
          {'reference': '$bookTitle סימן יב', 'segment': 120, 'level': 1},
          {
            'reference': '$bookTitle סימן יב סעיף א',
            'segment': 120,
            'level': 2
          },
          {
            'reference': '$bookTitle סימן יב סעיף ב',
            'segment': 122,
            'level': 2
          },
          {
            'reference': '$bookTitle סימן יב סעיף ג',
            'segment': 124,
            'level': 2
          },
          // ס"ק תחת סעיף א
          {
            'reference': '$bookTitle סימן יב סעיף א סק א',
            'segment': 120,
            'level': 3
          },
          {
            'reference': '$bookTitle סימן יב סעיף א סק ב',
            'segment': 121,
            'level': 3
          },
          {
            'reference': '$bookTitle סימן יב סעיף א סק ג',
            'segment': 121,
            'level': 3
          },
        ];

    FindRefRepository buildRepo({
      required String bookTitle,
      required int bookId,
      required String acronym,
      required List<Map<String, dynamic>> Function(String) tocBuilder,
      List<Map<String, dynamic>> Function(String)? altTocBuilder,
    }) =>
        FindRefRepository(
          dataRepository: MockDataRepository(),
          isReferenceBooksCacheLoaded: () => true,
          warmUpReferenceBooksCache: () async {},
          searchReferenceBooks: (query, {int limit = 50}) {
            if (query == acronym || query == bookTitle) {
              return [
                _hit(
                  bookId: bookId,
                  title: bookTitle,
                  normalizedTitle: bookTitle,
                  matchRank: query == bookTitle ? 0 : 3,
                  matchedTerm: query,
                )
              ];
            }
            return const <ReferenceBookHit>[];
          },
          getTocEntriesForReference: (id, title, {queryTokens}) async {
            final all = tocBuilder(title);
            if (queryTokens == null || queryTokens.isEmpty) return all;
            return _filterTocHierarchically(all, queryTokens, title);
          },
          getAltTocEntriesForReference: altTocBuilder == null
              ? null
              : (id, title, {queryTokens}) async {
                  if (queryTokens == null || queryTokens.isEmpty) {
                    return const [];
                  }
                  final all = altTocBuilder(title);
                  return _filterTocHierarchically(all, queryTokens, title);
                },
          getAllAltTocFlatEntries: altTocBuilder == null
              ? null
              : () async => [
                    for (final e in altTocBuilder(bookTitle))
                      {
                        'bookId': bookId,
                        'bookTitle': bookTitle,
                        'bookOrderIndex': 0.0,
                        'reference': e['reference'] as String,
                        'segment': e['segment'] as int,
                        'level': e['level'] as int,
                        'dbLineId': e['dbLineId'] as int? ?? 0,
                      }
                  ],
        );

    test('שבת עא ב — מוצא דף עא עמוד ב', () async {
      final repo = buildRepo(
        bookTitle: 'שבת',
        bookId: 1,
        acronym: 'שבת',
        tocBuilder: tractateToC,
      );

      final results = await repo.findRefs('שבת עא ב');

      expect(
        results.any((r) => r.reference.contains('עמוד ב') &&
            r.reference.contains('עא')),
        isTrue,
        reason: 'חייב למצוא את עמוד ב של דף עא',
      );
      expect(
        results.any((r) =>
            r.reference.contains('עמוד א') && r.reference.contains('עא')),
        isFalse,
        reason: 'עמוד א של עא לא אמור להיות בתוצאות',
      );
    });

    test('מב יב ג — מוצא סימן יב סעיף ג', () async {
      final repo = buildRepo(
        bookTitle: 'משנה ברורה',
        bookId: 2,
        acronym: 'מב',
        tocBuilder: shulchanToC,
      );

      final results = await repo.findRefs('מב יב ג');
      final refs = results.map((r) => r.reference).toList();

      expect(
        refs.any((r) => r.contains('סימן יב') && r.contains('סעיף ג')),
        isTrue,
        reason: 'חייב למצוא סימן יב סעיף ג',
      );
      expect(
        refs.any((r) => r.contains('סעיף א') || r.contains('סעיף ב')),
        isFalse,
        reason: 'סעיפים אחרים לא אמורים להופיע',
      );
    });

    test('מב יב סק ג — מוצא ס"ק ג (רמה 3)', () async {
      final repo = buildRepo(
        bookTitle: 'משנה ברורה',
        bookId: 2,
        acronym: 'מב',
        tocBuilder: shulchanToC,
      );

      final results = await repo.findRefs('מב יב סק ג');
      final refs = results.map((r) => r.reference).toList();

      expect(
        refs.any((r) =>
            r.contains('סימן יב') &&
            r.contains('סק ג')),
        isTrue,
        reason: 'חייב למצוא ס"ק ג של סימן יב',
      );
    });

    test('שבת טל ב — טרנספוזיציה: טל=לט, מוצא דף לט עמוד ב', () async {
      final repo = buildRepo(
        bookTitle: 'שבת',
        bookId: 1,
        acronym: 'שבת',
        tocBuilder: tractateToC,
      );

      final results = await repo.findRefs('שבת טל ב');

      expect(
        results.any((r) =>
            r.reference.contains('לט') && r.reference.contains('עמוד ב')),
        isTrue,
        reason: '"טל" הוא טרנספוזיציה של "לט" — חייב למצוא דף לט עמוד ב',
      );
    });

    // ── AltToc (כותרות-משנה) ──────────────────────────────────────────────────

    group('FindRef — חיפוש בכותרות-משנה (AltToc)', () {
      // AltToc references אינם כוללים שם הספר (הם יחסיים לספר).
      //   רמה 1: "פרשת לך לך"           (segment=100)
      //   רמה 2: "פרשת לך לך עליה א"   (segment=110)
      //          "פרשת לך לך עליה ו"   (segment=160)
      List<Map<String, dynamic>> altToc(String bookTitle) => [
            {'reference': 'פרשת לך לך', 'segment': 100, 'level': 1},
            {'reference': 'פרשת לך לך עליה א', 'segment': 110, 'level': 2},
            {'reference': 'פרשת לך לך עליה ו', 'segment': 160, 'level': 2},
          ];

      // TOC רגיל: פרקים (ללא קשר לעליות)
      List<Map<String, dynamic>> regularToc(String bookTitle) => [
            {'reference': '$bookTitle פרק יב', 'segment': 110, 'level': 1},
            {
              'reference': '$bookTitle פרק יב פסוק א',
              'segment': 110,
              'level': 2
            },
          ];

      test('חיפוש "לך ו" מוצא "עליה ו" דרך AltToc', () async {
        final repo = buildRepo(
          bookTitle: 'בראשית',
          bookId: 1,
          acronym: 'בראשית',
          tocBuilder: regularToc,
          altTocBuilder: altToc,
        );

        final results = await repo.findRefs('בראשית לך ו');
        final altResult = results.where((r) => r.isAltToc).toList();
        expect(altResult.any((r) => r.reference.contains('עליה ו')), isTrue,
            reason: '"בראשית לך ו" חייב למצוא "עליה ו" דרך AltToc');
        // reference ללא שם הספר
        expect(altResult.any((r) => r.reference.startsWith('בראשית')), isFalse,
            reason: 'AltToc reference לא אמור לכלול שם הספר');
      });

      test('חיפוש "לך א" מוצא "עליה א" דרך AltToc', () async {
        final repo = buildRepo(
          bookTitle: 'בראשית',
          bookId: 1,
          acronym: 'בראשית',
          tocBuilder: regularToc,
          altTocBuilder: altToc,
        );

        final results = await repo.findRefs('בראשית לך א');
        expect(
          results.any((r) => r.isAltToc && r.reference.contains('עליה א')),
          isTrue,
          reason: '"בראשית לך א" חייב למצוא "עליה א" דרך AltToc',
        );
      });

      test('AltToc מדורג: TOC L2 < AltToc < TOC L3+', () async {
        // repo מותאם-אישית: getTocEntriesForReference מחזיר L2 + L3 ישירות
        final repo = FindRefRepository(
          dataRepository: MockDataRepository(),
          isReferenceBooksCacheLoaded: () => true,
          warmUpReferenceBooksCache: () async {},
          searchReferenceBooks: (query, {int limit = 50}) {
            if (query == 'בראשית') {
              return [_hit(bookId: 1, title: 'בראשית')];
            }
            return const <ReferenceBookHit>[];
          },
          getTocEntriesForReference: (id, title, {queryTokens}) async => [
            {'reference': 'בראשית פרק א', 'segment': 10, 'level': 2},
            {'reference': 'בראשית פרק א פסוק א', 'segment': 11, 'level': 3},
          ],
          getAltTocEntriesForReference: (id, title, {queryTokens}) async => [
            {'reference': 'פרשת בראשית עליה א', 'segment': 12, 'level': 2},
          ],
        );

        final results = await repo.findRefs('בראשית א');
        final l2Idx = results.indexWhere((r) => !r.isAltToc && r.tocLevel == 2);
        final altIdx = results.indexWhere((r) => r.isAltToc);
        final l3Idx = results.indexWhere((r) => !r.isAltToc && r.tocLevel == 3);

        if (l2Idx != -1 && altIdx != -1) {
          expect(l2Idx, lessThan(altIdx),
              reason: 'TOC רמה 2 חייב להקדים AltToc');
        }
        if (altIdx != -1 && l3Idx != -1) {
          expect(altIdx, lessThan(l3Idx),
              reason: 'AltToc חייב להקדים TOC רמה 3+');
        }
      });

      test('חיפוש "לך ו" ללא שם הספר — global AltToc fallback', () async {
        final repo = buildRepo(
          bookTitle: 'בראשית',
          bookId: 1,
          acronym: 'בראשית',
          tocBuilder: regularToc,
          altTocBuilder: altToc,
        );

        // "לך ו" — ללא "בראשית"; searchReferenceBooks מחזיר ריק עבור "לך".
        // ה-fallback הגלובלי חייב למצוא "עליה ו" דרך AltToc של בראשית.
        final results = await repo.findRefs('לך ו');
        expect(
          results.any((r) => r.isAltToc && r.reference.contains('עליה ו')),
          isTrue,
          reason: '"לך ו" ללא שם הספר חייב למצוא "עליה ו" דרך global AltToc fallback',
        );
      });

      test('ללא altTocBuilder — AltToc לא מחזיר תוצאות', () async {
        final repo = buildRepo(
          bookTitle: 'בראשית',
          bookId: 1,
          acronym: 'בראשית',
          tocBuilder: regularToc,
          // altTocBuilder לא מועבר
        );

        final results = await repo.findRefs('בראשית לך ו');
        expect(
          results.any((r) => r.isAltToc),
          isFalse,
          reason: 'ללא AltToc — אין תוצאות עם isAltToc=true',
        );
      });
    });
  });

  // ─── נקודות רגישות ב-AltToc ────────────────────────────────────────────────

  group('FindRef — AltToc נקודות רגישות', () {
    test(
        'global fallback מופעל כשספר אחר נמצא אבל AltToc שלו לא מתאים',
        () async {
      // "תולדות עליה ב": "תולדות יצחק" נמצא כספר (bookHits לא ריק),
      // אבל AltToc שלו לא מחזיר תוצאות. ה-fallback חייב לרוץ ולמצוא בבראשית.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'תולדות') {
            return [
              _hit(bookId: 1, title: 'תולדות יצחק', normalizedTitle: 'תולדות יצחק'),
            ];
          }
          if (query == 'בראשית') {
            return [_hit(bookId: 2, title: 'בראשית', normalizedTitle: 'בראשית')];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async => const [],
        getAltTocEntriesForReference: (id, title, {queryTokens}) async {
          if (title == 'בראשית') {
            return [{'reference': 'תולדות עליה ב', 'segment': 100, 'level': 2}];
          }
          return const [];
        },
        getAllAltTocFlatEntries: () async => const [
          {
            'bookId': 2,
            'bookTitle': 'בראשית',
            'bookOrderIndex': 0.0,
            'reference': 'תולדות עליה ב',
            'segment': 100,
            'level': 2,
            'dbLineId': 0,
          }
        ],
      );

      final results = await repo.findRefs('תולדות עליה ב');
      expect(
        results.any((r) => r.isAltToc && r.reference.contains('עליה ב')),
        isTrue,
        reason: 'global fallback חייב לרוץ ולמצוא AltToc של בראשית',
      );
    });

    test('dedup: TOC ו-AltToc לאותו segment מחזירים תוצאה אחת', () async {
      // TOC מחזיר "ספר פרשת א" ו-AltToc מחזיר "פרשת א" — שניהם segment=50.
      // dedup לפי (title, segment) חייב להשאיר תוצאה אחת בלבד.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'ספר') {
            return [_hit(bookId: 1, title: 'ספר', normalizedTitle: 'ספר')];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async => [
          {'reference': 'ספר פרשת א', 'segment': 50, 'level': 2},
        ],
        getAltTocEntriesForReference: (id, title, {queryTokens}) async => [
          {'reference': 'פרשת א', 'segment': 50, 'level': 1},
        ],
      );

      final results = await repo.findRefs('ספר א');
      final withSegment50 = results.where((r) => r.segment == 50).toList();
      expect(
        withSegment50.length,
        1,
        reason: 'TOC ו-AltToc לאותו segment חייבים להתמזג לתוצאה אחת',
      );
    });

    test('פילטר AltToc פר-ספר — מאצ\' חלקי של ספר רפוי נחסם', () async {
      // "נחל שורק" נמצא עבור "נח" כי "נחל".startsWith("נח").
      // AltToc שלו מחזיר "הפטרת נח" שמתאים רק לטוקן "נח" ולא ל-"עליה" ו-"ב".
      // הפילטר remainingTokens חייב לחסום את התוצאה.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'נח') {
            return [
              _hit(bookId: 1, title: 'נחל שורק', normalizedTitle: 'נחל שורק', matchRank: 1),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async => const [],
        getAltTocEntriesForReference: (id, title, {queryTokens}) async => [
          {'reference': 'הפטרת נח', 'segment': 10, 'level': 1},
        ],
        getAllAltTocFlatEntries: () async => const [],
      );

      final results = await repo.findRefs('נח עליה ב');
      expect(
        results.any((r) => r.isAltToc),
        isFalse,
        reason: '"הפטרת נח" אינו מכיל "עליה" ו-"ב" — חייב להיחסם על-ידי הפילטר',
      );
    });

    test('global fallback — מאצ\' חלקי ב-AltToc נחסם על-ידי token filter', () async {
      // bookHits ריק; הקאש הגלובלי כולל ערך "הפטרת נח" של "נחל שורק".
      // queryTokens filter חייב לחסום — "עליה" ו-"ב" לא ב-reference.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) => const <ReferenceBookHit>[],
        getTocEntriesForReference: (id, title, {queryTokens}) async => const [],
        getAllAltTocFlatEntries: () async => const [
          {
            'bookId': 99,
            'bookTitle': 'נחל שורק',
            'bookOrderIndex': 0.0,
            'reference': 'הפטרת נח',
            'segment': 10,
            'level': 1,
            'dbLineId': 0,
          }
        ],
      );

      final results = await repo.findRefs('נח עליה ב');
      expect(
        results.any((r) => r.isAltToc),
        isFalse,
        reason: 'global fallback — "הפטרת נח" חסר "עליה" ו-"ב" ונחסם',
      );
    });

    test(
        'per-book מצא TOC L2+ — global fallback מדולג (רגרסיה: "ברכות ב" עם PDF)',
        () async {
      // הבאג ההיסטורי: ה-fallback רץ גם כש-per-book החזיר תוצאות פנימיות,
      // והוסיף false-positives שדחפו החוצה את ה-PDF של ברכות מתוך 15 התוצאות
      // הראשונות (כי `orderIndex` נבדק לפני `tocLevel`).
      // התיקון: התנאי החדש בודק `tocLevel >= 2 || isAltToc` — אם המסלול
      // ה-per-book כבר החזיר משהו ספציפי, הגלובלי לא רץ.
      var flatCacheCalled = false;
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'ברכות') {
            return [
              _hit(
                bookId: 1,
                title: 'ברכות',
                normalizedTitle: 'ברכות',
                fileType: 'pdf',
                filePath: '/books/brachot.pdf',
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async => [
          // התאמת TOC L2: "ברכות דף ב" — מהווה תוצאה ספציפית.
          {'reference': 'ברכות דף ב', 'segment': 2, 'level': 2},
        ],
        getAllAltTocFlatEntries: () async {
          flatCacheCalled = true;
          // לו ה-fallback היה רץ, ערך כזה היה עשוי להידחק קודם בגלל
          // orderIndex=0 נמוך.
          return const [
            {
              'bookId': 99,
              'bookTitle': 'בראשית',
              'bookOrderIndex': 0.0,
              'reference': 'פרק ה ברכות',
              'segment': 100,
              'level': 2,
              'dbLineId': 0,
            }
          ];
        },
      );

      final results = await repo.findRefs('ברכות ב');

      expect(flatCacheCalled, isFalse,
          reason: 'per-book החזיר TOC L2 → הגלובלי חייב להידלג');
      expect(results.any((r) => r.isPdf && r.title == 'ברכות'), isTrue,
          reason: 'PDF של ברכות נשאר ב-15 התוצאות הראשונות');
    });

    test('per-book מצא AltToc — global fallback מדולג', () async {
      // אם ה-per-book כבר מצא AltToc (תוצאה ספציפית), הגלובלי מיותר.
      var flatCacheCalled = false;
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'בראשית') {
            return [_hit(bookId: 1, title: 'בראשית', normalizedTitle: 'בראשית')];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAltTocEntriesForReference: (_, __, {queryTokens}) async => [
          {'reference': 'פרשת לך לך עליה ב', 'segment': 50, 'level': 2},
        ],
        getAllAltTocFlatEntries: () async {
          flatCacheCalled = true;
          return const [];
        },
      );

      await repo.findRefs('בראשית לך לך עליה ב');
      expect(flatCacheCalled, isFalse,
          reason: 'AltToc נמצא ב-per-book → global מדולג');
    });

    test('global flat cache: lazy, נבנה רק פעם אחת בכל ה-session', () async {
      // כמה שאילתות עוקבות שמפעילות את ה-fallback (per-book ריק) חייבות
      // לבנות את הקאש פעם אחת בלבד. כל קריאה לאחר מכן יושבת על קאש in-memory.
      var buildCount = 0;
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {int limit = 50}) =>
            const <ReferenceBookHit>[],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAllAltTocFlatEntries: () async {
          buildCount++;
          return const [];
        },
      );

      await repo.findRefs('נח עליה ב');
      await repo.findRefs('שמות פרק ה');
      await repo.findRefs('דברים פסוק יג');

      expect(buildCount, 1,
          reason: 'הקאש השטוח נבנה lazy, רק בקריאה הראשונה ל-fallback');
    });

    test(
        'global flat cache: כשל זמני בבנייה אינו "קופא" — שאילתה מאוחרת מנסה שוב',
        () async {
      // עם try/catch על בניית הקאש, חשוב שלא נקבע את הקאש לריק בכשל —
      // אחרת תקלה זמנית אחת תהרוס את ה-fallback לכל ה-session.
      var attempts = 0;
      var shouldFail = true;
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {int limit = 50}) =>
            const <ReferenceBookHit>[],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAllAltTocFlatEntries: () async {
          attempts++;
          if (shouldFail) throw Exception('DB error');
          return const [
            {
              'bookId': 1,
              'bookTitle': 'בראשית',
              'bookOrderIndex': 0.0,
              'reference': 'פרשת נח עליה ב',
              'segment': 50,
              'level': 2,
              'dbLineId': 0,
            }
          ];
        },
      );

      // כשל ראשון: התוצאה ריקה, אבל החריגה לא מתפשטת.
      final r1 = await repo.findRefs('נח עליה ב');
      expect(r1, isEmpty);
      expect(attempts, 1);

      // כשל שני: אם היינו "מקפיאים" את הקאש לריק, attempts היה נשאר 1.
      // התנהגות נכונה: ניסיון חוזר.
      final r2 = await repo.findRefs('נח עליה ב');
      expect(r2, isEmpty);
      expect(attempts, 2,
          reason: 'תקלה זמנית — שאילתה הבאה חייבת לנסות לבנות שוב');

      // הבעיה נפתרה: הניסיון הבא מצליח ומאכלס את הקאש.
      shouldFail = false;
      final r3 = await repo.findRefs('נח עליה ב');
      expect(r3.any((r) => r.isAltToc), isTrue,
          reason: 'אחרי שה-DB חוזרת לאיתנה — ה-fallback פועל');
      expect(attempts, 3);

      // אחרי הצלחה — הקאש נשמר ולא נבנה שוב.
      await repo.findRefs('שמות פרק ה');
      expect(attempts, 3, reason: 'אחרי הצלחה ראשונה הקאש in-memory');
    });

    test(
        'TOC L2 בספר "שגוי" → global מדולג גם אם AltToc נכון בספר אחר '
        '(תיעוד trade-off)', () async {
      // שאילתה אמביוולנטית: "תולדות עליה ב" — שתי פרשנויות אפשריות:
      //   (a) הפניה פנימית בספר "תולדות יצחק" (התאמת ספר מובילה לפי שם).
      //   (b) פרשת תולדות → עליה ב (AltToc גלובלי, בספר "בראשית").
      //
      // התנאי `perBookHasSpecificMatch` מדלג על ה-fallback ברגע ש-(a)
      // החזיר TOC L2+, כך ש-(b) לא יופיע. זה compromise מודע: חוסם
      // את ה-displacement של תוצאות PDF נכונות ע"י false-positives של
      // AltToc גלובלי (ראו "ברכות ב" למעלה), אבל מאבד פרשנות AltToc
      // לגיטימית במקרים אמביוולנטיים.
      //
      // אם הסמנטיקה הזו תרגיש כואבת — אפשר להחליף לתיקון מבוסס-דירוג
      // (`tocLevel` לפני `orderIndex` ב-`_rankResults`), שירוץ את ה-fallback
      // ויסמוך על המיון שלא ידחק תוצאות נכונות.
      var flatCacheCalled = false;
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'תולדות') {
            return [
              _hit(
                bookId: 1,
                title: 'תולדות יצחק',
                normalizedTitle: 'תולדות יצחק',
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [
          // התאמת TOC L2 בספר "השגוי" — מספיקה כדי לדלג על הגלובלי.
          {'reference': 'תולדות יצחק פרק עליה ב', 'segment': 5, 'level': 2},
        ],
        getAltTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAllAltTocFlatEntries: () async {
          flatCacheCalled = true;
          return const [
            {
              'bookId': 99,
              'bookTitle': 'בראשית',
              'bookOrderIndex': 0.0,
              'reference': 'פרשת תולדות עליה ב',
              'segment': 100,
              'level': 2,
              'dbLineId': 0,
            }
          ];
        },
      );

      final results = await repo.findRefs('תולדות עליה ב');

      expect(flatCacheCalled, isFalse,
          reason: 'TOC L2 ב-per-book → הגלובלי מדולג ע"י perBookHasSpecificMatch');
      expect(results.any((r) => r.isAltToc), isFalse,
          reason:
              'AltToc הגלובלי של "בראשית" לא מופיע — trade-off מודע של ההחלטה הזו');
    });

    test('global flat cache: ערכי NULL בשדות אופציונליים — לא קורסים', () async {
      // ה-cast ב-`_getAltTocFlatCache` חייב להיות סלחני: `bookOrderIndex` /
      // `segment` / `level` / `dbLineId` יכולים להיות null מ-DB ישן/חלקי
      // ולא להפיל את כל המסלול.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {int limit = 50}) =>
            const <ReferenceBookHit>[],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAllAltTocFlatEntries: () async => const [
          {
            'bookId': 5,
            'bookTitle': 'בראשית',
            // bookOrderIndex / segment / level / dbLineId — חסרים בכוונה.
            'reference': 'פרשת נח עליה ב',
          }
        ],
      );

      final results = await repo.findRefs('נח עליה ב');
      // לא נזרקה חריגה, וה-fallback הצליח להתאים את ה-entry.
      final alt = results.where((r) => r.isAltToc).toList();
      expect(alt, hasLength(1));
      expect(alt.single.bookId, 5);
      expect(alt.single.orderIndex, 999.0,
          reason: 'fallback ל-`bookOrderIndex` הוא 999 (סוף הספרייה)');
      expect(alt.single.segment, 0);
      expect(alt.single.tocLevel, 0);
      expect(alt.single.sourceLineId, 0);
    });
  });

  // ─── מיון לפי דורות + סגנון ציון ──────────────────────────────────────────

  group('FindRef — מיון לפי orderIndex וסגנון ציון', () {
    // בונה repo עם שני ספרים: גמרא (orderIndex גבוה) ומשנה (orderIndex נמוך)
    FindRefRepository buildTwoBookRepo({
      required List<Map<String, dynamic>> Function(String) talmudToc,
      required List<Map<String, dynamic>> Function(String) mishnaToc,
    }) {
      return FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'שבת' || query == 'מסכת שבת') {
            return [
              _hit(
                bookId: 10,
                title: 'מסכת שבת',
                normalizedTitle: 'מסכת שבת',
                matchRank: 0,
                orderIndex: 3000.0, // תלמוד בבלי — מאוחר יותר בספרייה
              ),
              _hit(
                bookId: 20,
                title: 'משנה מסכת שבת',
                normalizedTitle: 'משנה מסכת שבת',
                matchRank: 1,
                orderIndex: 1500.0, // משנה — קדומה יותר בספרייה
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async {
          final all =
              id == 10 ? talmudToc(title) : mishnaToc(title);
          if (queryTokens == null || queryTokens.isEmpty) return all;
          return _filterTocHierarchically(all, queryTokens, title);
        },
      );
    }

    List<Map<String, dynamic>> talmudShabbatToc(String title) => [
          {'reference': '$title דף עא', 'segment': 710, 'level': 1},
          {'reference': '$title דף עא עמוד א', 'segment': 710, 'level': 2},
          {'reference': '$title דף עא עמוד ב', 'segment': 715, 'level': 2},
        ];

    List<Map<String, dynamic>> mishnaShabbatToc(String title) => [
          {'reference': '$title פרק א', 'segment': 1, 'level': 1},
          {'reference': '$title פרק א משנה א', 'segment': 1, 'level': 2},
          {'reference': '$title פרק א משנה ב', 'segment': 2, 'level': 2},
        ];

    test('שבת בלבד — משנה (orderIndex נמוך) עולה לפני גמרא', () async {
      final repo = buildTwoBookRepo(
        talmudToc: talmudShabbatToc,
        mishnaToc: mishnaShabbatToc,
      );

      final results = await repo.findRefs('שבת');
      expect(results, isNotEmpty);

      final mishnaIdx =
          results.indexWhere((r) => r.title.contains('משנה'));
      final talmudIdx =
          results.indexWhere((r) => !r.title.contains('משנה'));

      expect(mishnaIdx, isNot(-1), reason: 'משנה חייבת להופיע');
      expect(talmudIdx, isNot(-1), reason: 'גמרא חייבת להופיע');
      expect(mishnaIdx, lessThan(talmudIdx),
          reason: '"שבת" בלבד: משנה (orderIndex נמוך) לפני גמרא');
    });

    test('שבת עא ב — גמרא (יש "דף") עולה לפני משנה', () async {
      final repo = buildTwoBookRepo(
        talmudToc: talmudShabbatToc,
        mishnaToc: mishnaShabbatToc,
      );

      final results = await repo.findRefs('שבת עא ב');
      expect(results, isNotEmpty);

      // הגמרא מחזירה "דף עא עמוד ב"; המשנה לא מחזירה תוצאה עבור "עא ב"
      // → הגמרא חייבת להיות ראשונה
      final first = results.first;
      expect(first.reference.contains('דף'), isTrue,
          reason: '"שבת עא ב" — ציון גמרא: התוצאה הראשונה חייבת להכיל "דף"');
    });

    test('"בראשית א ב" — לא מזוהה כגמרא (penultimate תו בודד)', () async {
      // הוריסטיקה: penultimate = "א" (1 תו) → לא ציון גמרא → citationMatch ניטרלי
      // → "תנ"ך" עם orderIndex נמוך יותר צריך לעלות ראשון
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'בראשית') {
            return [
              _hit(
                bookId: 1,
                title: 'ספר בראשית',
                normalizedTitle: 'ספר בראשית',
                matchRank: 1,
                orderIndex: 100.0, // תנ"ך — קדום
              ),
              _hit(
                bookId: 2,
                title: 'בראשית רבה',
                normalizedTitle: 'בראשית רבה',
                matchRank: 1,
                orderIndex: 5000.0, // מדרש — מאוחר יותר
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async {
          if (id == 1) {
            final all = <Map<String, dynamic>>[
              {'reference': '$title פרק א', 'segment': 0, 'level': 1},
              {'reference': '$title פרק א פסוק א', 'segment': 0, 'level': 2},
              {'reference': '$title פרק א פסוק ב', 'segment': 1, 'level': 2},
            ];
            if (queryTokens == null || queryTokens.isEmpty) return all;
            return _filterTocHierarchically(all, queryTokens, title);
          }
          return const [];
        },
      );

      final results = await repo.findRefs('בראשית א ב');
      expect(results, isNotEmpty);
      // ללא ציון גמרא — citationMatch ניטרלי לכל → orderIndex מכריע
      // ספר בראשית (100) לפני בראשית רבה (5000)
      final tanachIdx = results.indexWhere((r) => r.title == 'ספר בראשית');
      final midrashIdx = results.indexWhere((r) => r.title == 'בראשית רבה');
      if (tanachIdx != -1 && midrashIdx != -1) {
        expect(tanachIdx, lessThan(midrashIdx),
            reason: '"בראשית א ב" לא מוכר כגמרא — תנ"ך (orderIndex 100) לפני מדרש (5000)');
      }
    });

    test('orderIndex מבטיח סדר דורות כש-citationMatch שווה', () async {
      // שני ספרים ל"שבת", שניהם ללא TOC match (remainingTokens ריק)
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'שבת') {
            return [
              _hit(
                bookId: 1,
                title: 'אחרונים שבת',
                normalizedTitle: 'אחרונים שבת',
                matchRank: 1,
                orderIndex: 8000.0,
              ),
              _hit(
                bookId: 2,
                title: 'ראשונים שבת',
                normalizedTitle: 'ראשונים שבת',
                matchRank: 1,
                orderIndex: 4000.0,
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      final results = await repo.findRefs('שבת');
      final titles = results.map((r) => r.title).toList();

      final rishonimIdx = titles.indexWhere((t) => t.contains('ראשונים'));
      final acharonimIdx = titles.indexWhere((t) => t.contains('אחרונים'));

      expect(rishonimIdx, lessThan(acharonimIdx),
          reason: 'ראשונים (orderIndex 4000) לפני אחרונים (orderIndex 8000)');
    });

    test(
        'ספרי יסוד עולים מעל מפרשים גם כש-orderIndex של מפרש נמוך יותר',
        () async {
      // התרחיש: שאילתה "שבת יג". בספרייה יש:
      //   - "משנה שבת" (tier 2 — יסוד), orderIndex גבוה (יחסית).
      //   - "פירוש המגן על שבת" (מפרש, tier=null), orderIndex נמוך.
      // לפני התיקון של "ספרי יסוד" — המפרש היה דוחק את המשנה כי orderIndex
      // נבדק לפני tocLevel. עכשיו — tier 2 מנצח כל מי שאינו יסוד, ללא תלות
      // ב-orderIndex.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'שבת') {
            return [
              _hit(
                bookId: 1,
                title: 'משנה שבת',
                normalizedTitle: 'משנה שבת',
                matchRank: 1,
                orderIndex: 5000.0, // אחרי המפרש בספרייה
              ),
              _hit(
                bookId: 2,
                title: 'פירוש המגן על שבת',
                normalizedTitle: 'פירוש המגן על שבת',
                matchRank: 1,
                orderIndex: 1000.0, // לפני המשנה בספרייה
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async => [
          {'reference': '$title פרק יג', 'segment': 13, 'level': 2},
        ],
        getCategoryPathSync: (bookId) {
          if (bookId == 1) return 'משנה, סדר מועד'; // tier 2
          if (bookId == 2) return 'תלמוד בבלי, ראשונים, המגן, סדר מועד'; // null
          return null;
        },
      );

      final results = await repo.findRefs('שבת יג');
      expect(results, isNotEmpty);

      final mishnaIdx = results.indexWhere((r) => r.title == 'משנה שבת');
      final commentaryIdx =
          results.indexWhere((r) => r.title == 'פירוש המגן על שבת');

      expect(mishnaIdx, isNot(-1), reason: 'משנה שבת חייבת להופיע');
      expect(commentaryIdx, isNot(-1), reason: 'הפירוש חייב להופיע');
      expect(mishnaIdx, lessThan(commentaryIdx),
          reason: 'tier 2 (משנה) קודם ל-tier=null (פירוש), ללא תלות ב-orderIndex');
    });

    test(
        '"שבת יג" — סדר ה-tiers: משנה (2) → בבלי (3) → ירושלמי (4) → רמב"ם (8)',
        () async {
      // 4 ספרי יסוד מ-tiers שונים — לפי דרישת המשתמש, הסדר חייב להיות:
      //   משנה → בבלי → ירושלמי → רמב"ם.
      // ה-orderIndex לכולם זהה (5000) כדי לוודא שה-tier הוא המכריע ולא ה-sort.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'שבת') {
            return [
              _hit(
                bookId: 1,
                title: 'משנה שבת',
                normalizedTitle: 'משנה שבת',
                matchRank: 1,
                orderIndex: 5000.0,
              ),
              _hit(
                bookId: 2,
                title: 'שבת',
                normalizedTitle: 'שבת',
                matchRank: 0,
                orderIndex: 5000.0,
              ),
              _hit(
                bookId: 3,
                title: 'ירושלמי שבת',
                normalizedTitle: 'ירושלמי שבת',
                matchRank: 1,
                orderIndex: 5000.0,
              ),
              _hit(
                bookId: 4,
                title: 'משנה תורה, הלכות שבת',
                normalizedTitle: 'משנה תורה, הלכות שבת',
                matchRank: 1,
                orderIndex: 5000.0,
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async => [
          {'reference': '$title פרק יג', 'segment': 13, 'level': 2},
        ],
        getCategoryPathSync: (bookId) {
          switch (bookId) {
            case 1:
              return 'משנה, סדר מועד'; // tier 2
            case 2:
              return 'תלמוד בבלי, סדר מועד'; // tier 3
            case 3:
              return 'תלמוד ירושלמי, סדר מועד'; // tier 4
            case 4:
              return 'הלכה, משנה תורה, ספר זמנים'; // tier 8
            default:
              return null;
          }
        },
      );

      final results = await repo.findRefs('שבת יג');

      // איתור המופע הראשון של כל ספר. בכל בודק ש-tier קודם בא לפני tier
      // מאוחר יותר.
      final mishnaIdx = results.indexWhere((r) => r.title == 'משנה שבת');
      final bavliIdx = results.indexWhere((r) => r.title == 'שבת');
      final yerushalmiIdx =
          results.indexWhere((r) => r.title == 'ירושלמי שבת');
      final rambamIdx =
          results.indexWhere((r) => r.title == 'משנה תורה, הלכות שבת');

      expect([mishnaIdx, bavliIdx, yerushalmiIdx, rambamIdx],
          everyElement(isNot(-1)),
          reason: 'כל ארבעת הספרים חייבים להופיע ב-15 התוצאות הראשונות');
      expect(mishnaIdx, lessThan(bavliIdx),
          reason: 'tier 2 (משנה) לפני tier 3 (בבלי)');
      expect(bavliIdx, lessThan(yerushalmiIdx),
          reason: 'tier 3 (בבלי) לפני tier 4 (ירושלמי)');
      expect(yerushalmiIdx, lessThan(rambamIdx),
          reason: 'tier 4 (ירושלמי) לפני tier 8 (רמב"ם)');
    });
  });

  // ─── דחיית contains-only לרב-מילים ─────────────────────────────────────────

  group('FindRef — contains-only נדחה לרב-מילים', () {
    test('hit עם matchRank=2 נדחה כאשר השאילתה רב-מילים', () async {
      // וריאציה: שאילתה רב-מילים שמחזירה רק contains-only → התוצאה ריקה
      // ובסולם הביטויים יורדים למילה אחת.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'אור החיים') {
            return [
              _hit(
                bookId: 1,
                title: 'ספר אור החיים על התורה',
                normalizedTitle: 'ספר אור החיים על התורה',
                matchRank: 2, // contains-only — חייב להידחות
                orderIndex: 5.0,
              ),
            ];
          }
          if (query == 'אור') {
            return [_hit(bookId: 2, title: 'אור', orderIndex: 1.0)];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
      );

      final results = await repo.findRefs('אור החיים');

      expect(
        results.any((r) => r.title == 'ספר אור החיים על התורה'),
        isFalse,
        reason: 'matchRank=2 לרב-מילים חייב להידחות גם אם זה היחיד הזמין',
      );
    });
  });

  // ─── FS PDF (bookId=-1) ──────────────────────────────────────────────────────

  group('FindRef — FS PDF (bookId=-1)', () {
    // ספר PDF עם כותרת דו-מילית "ספר אטלס" כדי שניתן לקבל remainingTokens ריק.
    // שאילתה "ספר אטלס" → שתי המילים נצרכות ע"י הכותרת → remainingTokens=[].
    // שאילתה "ספר אטלס פרק" → remainingTokens=['פרק'].

    // outline entries: (normalizedTitle, originalTitle, pageNumber)
    final outline = [
      ('פרק א', 'פרק א', 10),
      ('פרק ב', 'פרק ב', 20),
      ('פרק ג', 'פרק ג', 30),
    ];

    FindRefRepository buildPdfRepo({
      List<(String, String, int)> Function(String)? outlineBuilder,
    }) =>
        FindRefRepository(
          dataRepository: MockDataRepository(),
          isReferenceBooksCacheLoaded: () => true,
          warmUpReferenceBooksCache: () async {},
          searchReferenceBooks: (query, {int limit = 50}) {
            if (query == 'ספר אטלס') {
              return [
                _hit(
                  bookId: -1,
                  title: 'ספר אטלס',
                  normalizedTitle: 'ספר אטלס',
                  fileType: 'pdf',
                  filePath: '/books/atlas.pdf',
                ),
              ];
            }
            return const <ReferenceBookHit>[];
          },
          getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
          getPdfOutlineEntries: outlineBuilder == null
              ? null
              : (path) async => outlineBuilder(path),
          getCategoryPath: (_) async => '',
        );

    test(
        'remainingTokens ריק — מחזיר כותרת הספר + כל פרקי ה-outline',
        () async {
      final repo = buildPdfRepo(outlineBuilder: (_) => outline);

      // "ספר אטלס" → שתי המילים ב-title → remainingTokens=[]
      final results = await repo.findRefs('ספר אטלס');
      final refs = results.map((r) => r.reference).toList();

      expect(refs, contains('ספר אטלס'),
          reason: 'כותרת הספר חייבת להיכלל');
      expect(refs, contains('ספר אטלס פרק א'));
      expect(refs, contains('ספר אטלס פרק ב'));
      expect(refs, contains('ספר אטלס פרק ג'));
    });

    test('remainingTokens לא ריק — מחזיר כל הפרקים התואמים (לא רק ראשון)',
        () async {
      // "ספר אטלס פרק" → remainingTokens=['פרק'] → כל שלושת הפרקים תואמים.
      final repo = buildPdfRepo(outlineBuilder: (_) => outline);

      final results = await repo.findRefs('ספר אטלס פרק');
      final refs = results.map((r) => r.reference).toList();

      expect(refs.where((r) => r.startsWith('ספר אטלס פרק')).length, equals(3),
          reason: 'כל שלושת הפרקים חייבים להיות בתוצאות (לא רק הראשון)');
    });

    test('remainingTokens לא ריק — מסנן פרקים לא תואמים', () async {
      // "ספר אטלס ב" → remainingTokens=['ב'] → רק "פרק ב" תואם
      final repo = buildPdfRepo(outlineBuilder: (_) => outline);

      final results = await repo.findRefs('ספר אטלס ב');
      final refs = results.map((r) => r.reference).toList();

      expect(refs, contains('ספר אטלס פרק ב'),
          reason: '"פרק ב" תואם ל-remainingToken "ב"');
      expect(refs.any((r) => r.contains('פרק א') || r.contains('פרק ג')),
          isFalse,
          reason: 'פרק א ו-פרק ג לא מכילים את הטוקן "ב"');
    });

    test('outline ריק + remainingTokens ריק — מחזיר כותרת בלבד', () async {
      final repo = buildPdfRepo(outlineBuilder: (_) => []);

      final results = await repo.findRefs('ספר אטלס');
      expect(results, hasLength(1));
      expect(results.single.reference, equals('ספר אטלס'));
    });

    test(
        'outline ריק + remainingTokens לא ריק — מחזיר ריק (כמו ספר DB ללא TOC match)',
        () async {
      final repo = buildPdfRepo(outlineBuilder: (_) => []);

      final results = await repo.findRefs('ספר אטלס פרק');
      expect(results, isEmpty,
          reason: 'outline ריק ללא התאמה — כמו ספר DB שה-TOC שלו לא מחזיר תוצאות');
    });

    test('outline entries מקבלים tocLevel=2', () async {
      final repo = buildPdfRepo(outlineBuilder: (_) => outline);

      final results = await repo.findRefs('ספר אטלס');
      final chapterResults =
          results.where((r) => r.reference != 'ספר אטלס').toList();

      expect(chapterResults.every((r) => r.tocLevel == 2), isTrue,
          reason: 'פרקי outline מטופלים כ-TOC רמה 2');
    });

    test(
        'שני FS PDFs בעלי אותה כותרת אך filePath שונה — שניהם שורדים '
        'את ה-dedupe (P2 רגרסיה)', () async {
      // לכל FS PDF יש bookId == -1. שני קבצים שונים מהדיסק יכולים לחלוק
      // כותרת (גרסאות שונות של אותו ספר), וההבדל היחיד ביניהם הוא ה-filePath.
      // dedupe ללא filePath היה מאחד אותם משרירותיות; ב-Dedupe הנוכחי
      // filePath נכלל למפתח רק כש-bookId == -1, כדי לשמור על האיחוד הנכון
      // של תוצאות DB עם filePath ידוע/ריק.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'ספר אטלס') {
            return [
              _hit(
                bookId: -1,
                title: 'ספר אטלס',
                normalizedTitle: 'ספר אטלס',
                fileType: 'pdf',
                filePath: '/books/atlas-v1.pdf',
              ),
              _hit(
                bookId: -1,
                title: 'ספר אטלס',
                normalizedTitle: 'ספר אטלס',
                fileType: 'pdf',
                filePath: '/books/atlas-v2.pdf',
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        // outline ריק לשני הקבצים — נשארת רק תוצאה אחת לכל קובץ (הכותרת).
        getPdfOutlineEntries: (_) async => const [],
        getCategoryPath: (_) async => '',
      );

      final results = await repo.findRefs('ספר אטלס');

      // שתי תוצאות — אחת לכל קובץ — שתיהן עם אותו title אך filePath שונה.
      expect(results, hasLength(2),
          reason: 'שני קבצי PDF שונים לא יכולים להתאחד ע"י dedupe');
      final filePaths = results.map((r) => r.filePath).toSet();
      expect(filePaths,
          equals({'/books/atlas-v1.pdf', '/books/atlas-v2.pdf'}));
    });
  });

  // ─── bookId ו-bookPath ───────────────────────────────────────────────────────

  group('FindRef — bookId ו-bookPath', () {
    test('bookId מועבר נכון לתוצאות ממאגר נתונים', () async {
      // ודא ש-bookId=7 של הספר נשמר בתוצאה.
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'בראשית') {
            return [_hit(bookId: 7, title: 'בראשית', orderIndex: 1.0)];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getCategoryPath: (_) async => '',
      );

      final results = await repo.findRefs('בראשית א');
      expect(
        results.every((r) => r.bookId == 7),
        isTrue,
        reason: 'כל תוצאה לספר bookId=7 חייבת לשאת bookId=7',
      );
    });

    test('bookPath מולא מ-getCategoryPath בתוצאות DB', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'בראשית') {
            return [
              _hit(bookId: 5, title: 'בראשית', normalizedTitle: 'בראשית'),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (id, title, {queryTokens}) async => [
          {'reference': 'בראשית פרק א', 'segment': 10, 'level': 2},
        ],
        getCategoryPath: (id) async => id == 5 ? 'תנך, תורה, בראשית' : '',
      );

      final results = await repo.findRefs('בראשית פרק');
      expect(
        results.every((r) => r.bookPath == 'תנך, תורה, בראשית'),
        isTrue,
        reason: 'bookPath חייב להיות מולא מ-getCategoryPath',
      );
    });

    test('bookId מועבר לתוצאות AltToc של global fallback', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {int limit = 50}) =>
            const <ReferenceBookHit>[],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAltTocEntriesForReference: (id, title, {queryTokens}) async => [
          {'reference': 'נח עליה ב', 'segment': 200, 'level': 2},
        ],
        getAllAltTocFlatEntries: () async => const [
          {
            'bookId': 42,
            'bookTitle': 'בראשית',
            'bookOrderIndex': 0.0,
            'reference': 'נח עליה ב',
            'segment': 200,
            'level': 2,
            'dbLineId': 0,
          }
        ],
        getCategoryPath: (id) async => id == 42 ? 'תנך, תורה' : '',
      );

      final results = await repo.findRefs('נח עליה ב');
      final altResult =
          results.where((r) => r.isAltToc).toList();

      expect(altResult, isNotEmpty,
          reason: 'global fallback חייב להחזיר תוצאת AltToc');
      expect(
        altResult.every((r) => r.bookId == 42),
        isTrue,
        reason: 'bookId חייב להיות 42 (מ-getAllAltTocFlatEntries)',
      );
      expect(
        altResult.every((r) => r.bookPath == 'תנך, תורה'),
        isTrue,
        reason: 'bookPath חייב להיות מולא מ-getCategoryPath',
      );
    });

    test('FS PDF (bookId=-1) — bookPath נשאר ריק', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'אטלס') {
            return [
              _hit(
                bookId: -1,
                title: 'אטלס',
                fileType: 'pdf',
                filePath: '/books/atlas.pdf',
              ),
            ];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getCategoryPath: (_) async => 'לא אמור להיקרא',
      );

      final results = await repo.findRefs('אטלס מפה');
      expect(
        results.every((r) => r.bookPath.isEmpty),
        isTrue,
        reason: 'FS PDF עם bookId=-1 לא יכול לקבל bookPath',
      );
    });

    test('bookPath ריק כשספר לא נמצא (getCategoryPath מחזיר ריק)', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'ספר') {
            return [_hit(bookId: 99, title: 'ספר', orderIndex: 1.0)];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => [
          {'reference': 'ספר פרק א', 'segment': 1, 'level': 2},
        ],
        getCategoryPath: (_) async => '',
      );

      final results = await repo.findRefs('ספר פרק');
      expect(
        results.every((r) => r.bookPath.isEmpty),
        isTrue,
        reason: 'כשהנתיב ריק, bookPath חייב להישאר ריק',
      );
    });

    test('bookId מועבר בשאילתת מילה בודדת', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (query, {int limit = 50}) {
          if (query == 'שמות') {
            return [_hit(bookId: 11, title: 'שמות', orderIndex: 2.0)];
          }
          return const <ReferenceBookHit>[];
        },
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getCategoryPath: (id) async => id == 11 ? 'תנך, תורה, שמות' : '',
      );

      final results = await repo.findRefs('שמות');
      expect(results, hasLength(1));
      expect(results.single.bookId, equals(11),
          reason: 'שאילתת מילה בודדת חייבת לשמור bookId');
      expect(results.single.bookPath, equals('תנך, תורה, שמות'),
          reason: 'שאילתת מילה בודדת חייבת לקבל bookPath');
    });
  });

  // ─── ספרים אישיים (includePersonalBooks) ─────────────────────────────────────

  final personalBook = (
    id: 99,
    title: 'ספר פרטי',
    filePath: null,
    fileType: 'txt',
    orderIndex: 1.0,
  );

  FindRefRepository buildPersonalRepo({
    List<Map<String, dynamic>> userToc = const [],
  }) =>
      FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {limit = 50}) => const [],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAllUserBooks: () async => [personalBook],
        getUserBookTocEntries: (_, __, {queryTokens}) async => userToc,
      );

  group('FindRef — ספרים אישיים (includePersonalBooks)', () {
    test('כשהסוויצ כבוי — ספרים אישיים לא מוחזרים', () async {
      final repo = buildPersonalRepo();
      final results = await repo.findRefs('ספר פרטי');
      expect(results.where((r) => r.bookPath == 'ספרים אישיים'), isEmpty);
    });

    test('שאילתת מילה בודדת — מחזיר כותרת ספר עם bookPath=ספרים אישיים',
        () async {
      final repo = buildPersonalRepo();
      final results =
          await repo.findRefs('ספר', includePersonalBooks: true);
      final personal = results.where((r) => r.bookPath == 'ספרים אישיים');
      expect(personal, isNotEmpty);
      expect(personal.first.title, equals('ספר פרטי'));
      expect(personal.first.segment, equals(0));
    });

    test('שאילתת שתי מילים ו-remainingTokens ריק — כותרת + TOC רמה 2',
        () async {
      final repo = buildPersonalRepo(userToc: [
        {'reference': 'ספר פרטי פרק א', 'segment': 10, 'level': 2},
        {'reference': 'ספר פרטי פרק ב', 'segment': 20, 'level': 2},
      ]);
      final results =
          await repo.findRefs('ספר פרטי', includePersonalBooks: true);
      final refs = results
          .where((r) => r.bookPath == 'ספרים אישיים')
          .map((r) => r.reference)
          .toList();
      expect(refs, contains('ספר פרטי'));
      expect(refs, contains('ספר פרטי פרק א'));
      expect(refs, contains('ספר פרטי פרק ב'));
    });

    test('שאילתה עם remainingTokens — מחזיר רק TOC תואם', () async {
      final repo = buildPersonalRepo(userToc: [
        {'reference': 'ספר פרטי פרק א', 'segment': 10, 'level': 2},
      ]);
      final results =
          await repo.findRefs('ספר פרטי פרק', includePersonalBooks: true);
      final personal = results
          .where((r) => r.bookPath == 'ספרים אישיים')
          .toList();
      expect(personal, hasLength(1));
      expect(personal.first.reference, equals('ספר פרטי פרק א'));
    });

    test('ספר שלא מתאים לשאילתה — לא מוחזר', () async {
      final repo = buildPersonalRepo();
      final results =
          await repo.findRefs('בראשית', includePersonalBooks: true);
      expect(results.where((r) => r.bookPath == 'ספרים אישיים'), isEmpty);
    });

    test('bookPath של ספר אישי לא נדרס ע"י getCategoryPath', () async {
      // ספר אישי עם id=42 לא צריך לקבל את הנתיב של הספר הרשמי 42
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {limit = 50}) => const [],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAllUserBooks: () async => [
          (
            id: 42,
            title: 'ספר אישי',
            filePath: null,
            fileType: 'txt',
            orderIndex: 1.0,
          )
        ],
        getUserBookTocEntries: (_, __, {queryTokens}) async => const [],
        getCategoryPath: (_) async => 'נתיב רשמי שגוי',
      );
      final results =
          await repo.findRefs('ספר אישי', includePersonalBooks: true);
      final personal =
          results.where((r) => r.title == 'ספר אישי').toList();
      expect(personal, isNotEmpty);
      expect(personal.first.bookPath, equals('ספרים אישיים'),
          reason: 'bookPath של ספר אישי לא צריך להידרס ע"י getCategoryPath');
    });

    test('רשימת ספרים אישיים ריקה — אין קריסה', () async {
      final repo = FindRefRepository(
        dataRepository: MockDataRepository(),
        isReferenceBooksCacheLoaded: () => true,
        warmUpReferenceBooksCache: () async {},
        searchReferenceBooks: (_, {limit = 50}) => const [],
        getTocEntriesForReference: (_, __, {queryTokens}) async => const [],
        getAllUserBooks: () async => [],
        getUserBookTocEntries: (_, __, {queryTokens}) async => const [],
      );
      final results =
          await repo.findRefs('ספר', includePersonalBooks: true);
      expect(results.where((r) => r.bookPath == 'ספרים אישיים'), isEmpty);
    });
  });
}

