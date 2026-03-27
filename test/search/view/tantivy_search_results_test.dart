import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/view/tantivy_search_results.dart';

void main() {
  group('findUniqueTextBookForSearchResult', () {
    test('מחזיר ספר טקסט כשיש התאמה יחידה', () {
      final library = Library(categories: [
        Category(
          title: 'הלכה',
          description: '',
          shortDescription: '',
          order: 0,
          subCategories: [],
          books: [
            TextBook(title: 'ספר א', categoryId: 10),
          ],
          parent: null,
        ),
      ]);

      final book = findUniqueTextBookForSearchResult(library, 'ספר א');

      expect(book, isNotNull);
      expect(book!.categoryId, 10);
    });

    test('מחזיר null כשיש יותר מהתאמה אחת', () {
      final library = Library(categories: [
        Category(
          title: 'קבוצה',
          description: '',
          shortDescription: '',
          order: 0,
          subCategories: [],
          books: [
            TextBook(title: 'ספר כפול', categoryId: 10),
            TextBook(title: 'ספר כפול', categoryId: 20),
          ],
          parent: null,
        ),
      ]);

      final book = findUniqueTextBookForSearchResult(library, 'ספר כפול');

      expect(book, isNull);
    });
  });
}
