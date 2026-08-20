import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/models/catalogue_order_resolver.dart';

void main() {
  group('CatalogueOrderResolver', () {
    test('ספר שבספרייה מקבל את הסדר שנקבע לו', () {
      final resolver = CatalogueOrderResolver({'id:1': 0, 'id:2': 1});

      expect(resolver.orderFor('id:1'), 0);
      expect(resolver.orderFor('id:2'), 1);
    });

    test('ספר שאינו במפת הקטלוג נדחה לפני יצירת מזהה מסמך', () {
      final resolver = CatalogueOrderResolver({'id:1': 0});

      expect(
        () => resolver.orderFor('uid:404'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('uid:404'),
          ),
        ),
      );
    });

    test('מפתחות בעלי גיבוב זהה אינם מקבלים סדר משותף או תלוי-קריאה', () {
      final resolver = CatalogueOrderResolver({'id:1': 0});

      for (final key in const [
        'uid:1h5o88x:yde',
        'uid:1x7q2cs:18w3',
      ]) {
        expect(() => resolver.orderFor(key), throwsStateError);
      }
    });

    test('הסדר המרבי החוקי מתקבל', () {
      final resolver = CatalogueOrderResolver({
        'id:last': CatalogueOrderResolver.maxCatalogueOrder,
      });

      expect(
        resolver.orderFor('id:last'),
        CatalogueOrderResolver.maxCatalogueOrder,
      );
    });

    test('סדר שחורג מטווח u64 נדחה לפני המעבר למנוע', () {
      final resolver = CatalogueOrderResolver({
        'id:overflow': CatalogueOrderResolver.maxCatalogueOrder + 1,
      });

      expect(() => resolver.orderFor('id:overflow'), throwsRangeError);
    });

    test('סדר שלילי נדחה', () {
      final resolver = CatalogueOrderResolver({'id:negative': -1});

      expect(() => resolver.orderFor('id:negative'), throwsRangeError);
    });
  });
}
