import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/find_ref/find_ref_repository.dart';
import 'package:otzaria/find_ref/reference_books_cache.dart';

class MockDataRepository extends Mock implements DataRepository {}

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
}

