import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/book_facet.dart';

void main() {
  group('BookFacet.findMatchingBook', () {
    test('מעדיף מזהה יציב על פני כותרת בלבד כאשר יש ספרים כפולי-שם', () {
      final first = TextBook(
        id: 11,
        title: 'שבת',
        categoryPath: '/תלמוד בבלי/סדר מועד',
        fileType: 'txt',
      );
      final second = TextBook(
        id: 22,
        title: 'שבת',
        categoryPath: '/הלכה',
        fileType: 'txt',
      );

      final match = BookFacet.findMatchingBook(
        [first, second],
        title: 'שבת',
        type: TextBook,
        bookId: 22,
        categoryPath: '/הלכה',
        fileType: 'txt',
      );

      expect(match, same(second));
    });

    test('מעדיף נתיב קובץ עבור ספרי PDF עם אותו שם', () {
      final first = PdfBook(
        title: 'סידור',
        path: r'C:\books\a.pdf',
        fileType: 'pdf',
      );
      final second = PdfBook(
        title: 'סידור',
        path: r'C:\books\b.pdf',
        fileType: 'pdf',
      );

      final match = BookFacet.findMatchingBook(
        [first, second],
        title: 'סידור',
        type: PdfBook,
        fileType: 'pdf',
        filePath: r'C:\books\b.pdf',
      );

      expect(match, same(second));
    });
  });

  group('BookFacet.resolveTopics fallback normalization', () {
    test('מנרמל categoryPath בפורמט /a/b ל-topics בפורמט a, b', () {
      final facetPath = BookFacet.buildFacetPath(
        title: 'בראשית',
        topics: 'תנ"ך, תורה',
        bookId: 1,
      );

      expect(facetPath, '/תנ"ך/תורה/id:1');
    });
  });
}
