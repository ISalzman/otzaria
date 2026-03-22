import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/utils/facet_helper.dart';

class _FakeSearchResult {
  final String title;

  _FakeSearchResult(this.title);
}

void main() {
  group('FacetHelper.buildFacetCountsFromResults', () {
    test('מחשב ספירות עבור שורש, אבות וספרים', () {
      final bookByTitle = <String, Book>{
        'בראשית': TextBook(
          title: 'בראשית',
          categoryPath: '/תנ"ך/תורה',
        ),
        'ברכות': TextBook(
          title: 'ברכות',
          categoryPath: '/משנה/זרעים',
        ),
      };

      final counts = FacetHelper.buildFacetCountsFromResults(
        [
          _FakeSearchResult('בראשית'),
          _FakeSearchResult('ברכות'),
        ],
        bookByTitle,
      );

      expect(counts['/'], 2);
      expect(counts['/תנ"ך'], 1);
      expect(counts['/תנ"ך/תורה'], 1);
      expect(counts['/תנ"ך/תורה/בראשית'], 1);
      expect(counts['/משנה'], 1);
      expect(counts['/משנה/זרעים'], 1);
      expect(counts['/משנה/זרעים/ברכות'], 1);
    });
  });
}
