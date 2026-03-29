import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/utils/search_catalogue_order_helper.dart';

class _FakeResult {
  final String title;
  final int marker;

  const _FakeResult(this.title, this.marker);
}

void main() {
  group('SearchCatalogueOrderHelper', () {
    test('sortByLibraryOrder ממיין מסכתות לפי הסדר הקטלוגי של הספרייה', () {
      final library = _buildLibrary();
      final results = [
        const _FakeResult('חגיגה', 0),
        const _FakeResult('שבת', 1),
      ];

      final sorted = SearchCatalogueOrderHelper.sortByLibraryOrder(
        results,
        library,
        titleOf: (result) => result.title,
      );

      expect(sorted.map((result) => result.title).toList(), ['שבת', 'חגיגה']);
    });

    test('sortByLibraryOrder שומר על override של קטגוריות עליונות', () {
      final library = _buildLibrary();
      final results = [
        const _FakeResult('משנה תורה, הלכות שבת', 0),
        const _FakeResult('שבת', 1),
      ];

      final sorted = SearchCatalogueOrderHelper.sortByLibraryOrder(
        results,
        library,
        titleOf: (result) => result.title,
      );

      expect(
        sorted.map((result) => result.title).toList(),
        ['שבת', 'משנה תורה, הלכות שבת'],
      );
    });

    test('sortByLibraryOrder מציב תנ"ך לפני תלמוד בבלי', () {
      final library = _buildLibrary();
      final results = [
        const _FakeResult('שבת', 0),
        const _FakeResult('בראשית', 1),
      ];

      final sorted = SearchCatalogueOrderHelper.sortByLibraryOrder(
        results,
        library,
        titleOf: (result) => result.title,
      );

      expect(sorted.map((result) => result.title).toList(), ['בראשית', 'שבת']);
    });

    test('sortByLibraryOrder שומר על הסדר המקורי בתוך אותו ספר', () {
      final library = _buildLibrary();
      final results = [
        const _FakeResult('שבת', 10),
        const _FakeResult('שבת', 20),
        const _FakeResult('חגיגה', 30),
      ];

      final sorted = SearchCatalogueOrderHelper.sortByLibraryOrder(
        results,
        library,
        titleOf: (result) => result.title,
      );

      expect(sorted.map((result) => result.marker).toList(), [10, 20, 30]);
    });
  });
}

Library _buildLibrary() {
  final library = Library(categories: []);
  final tanakh = Category(
    title: 'תנ"ך',
    description: '',
    shortDescription: '',
    order: 999,
    subCategories: [],
    books: [],
    parent: library,
  );
  final bavli = Category(
    title: 'תלמוד בבלי',
    description: '',
    shortDescription: '',
    order: 999,
    subCategories: [],
    books: [],
    parent: library,
  );
  final halacha = Category(
    title: 'הלכה',
    description: '',
    shortDescription: '',
    order: 1,
    subCategories: [],
    books: [],
    parent: library,
  );
  library.subCategories.addAll([halacha, bavli, tanakh]);

  tanakh.books.add(
    TextBook(title: 'בראשית', order: 1, category: tanakh),
  );

  final moed = Category(
    title: 'סדר מועד',
    description: '',
    shortDescription: '',
    order: 5,
    subCategories: [],
    books: [],
    parent: bavli,
  );
  bavli.subCategories.add(moed);

  moed.books.addAll([
    TextBook(title: 'שבת', order: 1, category: moed),
    TextBook(title: 'חגיגה', order: 11, category: moed),
  ]);

  halacha.books.add(
    TextBook(title: 'משנה תורה, הלכות שבת', order: 1, category: halacha),
  );

  return library;
}
