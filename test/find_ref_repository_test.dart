import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/find_ref/repository/find_ref_repository.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';

class MockDataRepository extends Mock implements DataRepository {}

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

