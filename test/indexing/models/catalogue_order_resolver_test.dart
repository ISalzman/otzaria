import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/models/catalogue_order_resolver.dart';

void main() {
  group('CatalogueOrderResolver', () {
    test('ספר שבספרייה מקבל את הסדר שנקבע לו', () {
      final resolver = CatalogueOrderResolver({'id:1': 0, 'id:2': 1});

      expect(resolver.orderFor('id:1'), 0);
      expect(resolver.orderFor('id:2'), 1);
      expect(resolver.fallbackKeys, isEmpty);
    });

    test('שני ספרים שאינם בספרייה מקבלים סדר שונה', () {
      // רגרסיה: סדר משותף ⇒ מזהי מסמך זהים, והמנוע מוחק לפי id — כתיבת
      // ספר אחד הייתה מוחקת את מסמכי האחר, והם חלקו גם sectionId.
      final resolver = CatalogueOrderResolver({'id:1': 0, 'id:2': 1});

      final first = resolver.orderFor('uid:404');
      final second = resolver.orderFor('uid:405');

      expect(first, isNot(second));
      expect(resolver.fallbackKeys, {'uid:404', 'uid:405'});
    });

    test('הסדר החלופי בא אחרי הספר האחרון שבספרייה', () {
      final resolver = CatalogueOrderResolver({'id:1': 0, 'id:2': 7});

      expect(resolver.orderFor('uid:404'), 8);
      expect(resolver.orderFor('uid:405'), 9);
    });

    test('מפתח חסר חוזר מחזיר את אותו סדר — לא מקצה חדש בכל קריאה', () {
      final resolver = CatalogueOrderResolver({'id:1': 0});

      final first = resolver.orderFor('uid:404');

      expect(resolver.orderFor('uid:404'), first);
      expect(resolver.fallbackKeys, hasLength(1));
    });

    test('ספרייה ריקה — הסדר החלופי מתחיל מאפס', () {
      final resolver = CatalogueOrderResolver({});

      expect(resolver.orderFor('uid:404'), 0);
      expect(resolver.orderFor('uid:405'), 1);
    });

    test('מזהי המסמכים של שני ספרים חסרים אינם מתנגשים באותה שורה', () {
      final resolver = CatalogueOrderResolver({'id:1': 0});

      final ids = {
        for (final key in ['uid:404', 'uid:405'])
          key: [
            for (var line = 0; line < 3; line++)
              (BigInt.from(resolver.orderFor(key) + 1) << 32) +
                  BigInt.from(line + 1),
          ],
      };

      expect(
        ids['uid:404']!.toSet().intersection(ids['uid:405']!.toSet()),
        isEmpty,
      );
    });

    test('חריגה מטווח הסדר זורקת במקום לגלוש מעבר ל-u64', () {
      final resolver = CatalogueOrderResolver({
        'id:1': CatalogueOrderResolver.maxCatalogueOrder,
      });

      expect(() => resolver.orderFor('uid:404'), throwsStateError);
    });

    test('הסדר המרבי נשאר בתוך u64 גם בשורות מאוחרות', () {
      final u64Max = (BigInt.one << 64) - BigInt.one;
      final id =
          (BigInt.from(CatalogueOrderResolver.maxCatalogueOrder + 1) << 32) +
          BigInt.from(1000000);

      expect(id, lessThanOrEqualTo(u64Max));
    });
  });
}
