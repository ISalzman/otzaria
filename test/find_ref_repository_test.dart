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
}

