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
}
