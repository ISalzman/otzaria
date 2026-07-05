import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/utils/category_query_parser.dart';

Category _category(String title, List<Book> books,
        {List<Category> sub = const []}) =>
    Category(
      title: title,
      description: '',
      shortDescription: '',
      order: 0,
      subCategories: sub,
      books: books,
      parent: null,
    );

void main() {
  group('parseCategoryQuery', () {
    test('ללא @ — מחזיר את השאילתה כמות שהיא ו-facets null', () {
      final library = Library(categories: [
        _category('תורה', [TextBook(title: 'בראשית')]),
      ]);

      final parsed = parseCategoryQuery('שלום עולם', library);

      expect(parsed.query, 'שלום עולם');
      expect(parsed.hasCategoryToken, isFalse);
      expect(parsed.facets, isNull);
    });

    test('@קטגוריה — מוצא את נתיב הקטגוריה', () {
      final library = Library(categories: [
        _category('תורה', [TextBook(title: 'בראשית')]),
      ]);

      final parsed = parseCategoryQuery('שלום@תורה', library);

      expect(parsed.query, 'שלום');
      expect(parsed.hasCategoryToken, isTrue);
      expect(parsed.categoryFound, isTrue);
      expect(parsed.facets, contains('/תורה'));
    });

    test('@ספר — מוצא את ה-facet של הספר', () {
      final library = Library(categories: [
        _category('תורה', [TextBook(title: 'בראשית')]),
      ]);

      final parsed = parseCategoryQuery('שלום@בראשית', library);

      expect(parsed.query, 'שלום');
      expect(parsed.categoryFound, isTrue);
      // ה-facet של ספר כולל את המפתח הייחודי של הספר בסוף הנתיב.
      expect(parsed.facets!.single, contains('בראשית'));
    });

    test('@שם שלא קיים — token קיים אך אין התאמה', () {
      final library = Library(categories: [
        _category('תורה', [TextBook(title: 'בראשית')]),
      ]);

      final parsed = parseCategoryQuery('שלום@לא-קיים', library);

      expect(parsed.hasCategoryToken, isTrue);
      expect(parsed.categoryFound, isFalse);
      expect(parsed.facets, isEmpty);
    });

    test('@ ריק — מתעלם מהתחביר', () {
      final library = Library(categories: []);

      final parsed = parseCategoryQuery('שלום@', library);

      expect(parsed.query, 'שלום');
      expect(parsed.hasCategoryToken, isFalse);
    });
  });
}
