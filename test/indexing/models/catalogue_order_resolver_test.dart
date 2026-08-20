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

    test('מפתח חסר חוזר מחזיר את אותו סדר — לא מקצה חדש בכל קריאה', () {
      final resolver = CatalogueOrderResolver({'id:1': 0});

      final first = resolver.orderFor('uid:404');

      expect(resolver.orderFor('uid:404'), first);
      expect(resolver.fallbackKeys, hasLength(1));
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

    test('הסדר החלופי ממוין אחרי כל ספר אפשרי בספרייה', () {
      final resolver = CatalogueOrderResolver({'id:1': 0, 'id:2': 7});

      // מיליון ספרים הוא הרבה מעבר לספרייה בפועל, והטווח השמור מעליהם.
      expect(resolver.orderFor('uid:404'), greaterThan(1000000));
      expect(
        resolver.orderFor('uid:404'),
        lessThanOrEqualTo(CatalogueOrderResolver.maxCatalogueOrder),
      );
    });

    test('אותו מפתח מקבל אותו סדר במוסרים נפרדים — יציב בין ריצות', () {
      // רגרסיה: הקצאה לפי מונה רץ נתנה לספר חסר סדר שתלוי במי נשאל לפניו,
      // ולכן ריצה אחרת חילקה אותו סדר לספר אחר — מזהי מסמך מתנגשים.
      final first = CatalogueOrderResolver({'id:1': 0});
      final second = CatalogueOrderResolver({'id:1': 0, 'id:2': 1, 'id:3': 2});

      first.orderFor('uid:999');

      expect(second.orderFor('uid:404'), first.orderFor('uid:404'));
    });

    test('סדר הקריאות אינו משפיע על הסדר שמוקצה', () {
      final ascending = CatalogueOrderResolver({'id:1': 0});
      final descending = CatalogueOrderResolver({'id:1': 0});

      ascending.orderFor('uid:404');
      ascending.orderFor('uid:405');
      descending.orderFor('uid:405');
      descending.orderFor('uid:404');

      expect(ascending.orderFor('uid:404'), descending.orderFor('uid:404'));
      expect(ascending.orderFor('uid:405'), descending.orderFor('uid:405'));
    });

    test('הגיבוב יציב ואינו נשען על hashCode', () {
      expect(
        CatalogueOrderResolver.stableFallbackHash('uid:404'),
        CatalogueOrderResolver.stableFallbackHash('uid:404'),
      );
      expect(
        CatalogueOrderResolver.stableFallbackHash('uid:404'),
        isNot(CatalogueOrderResolver.stableFallbackHash('uid:405')),
      );
      // ערך מקובע: שינוי במימוש הגיבוב משנה מזהים שכבר נצרבו לאינדקס.
      expect(CatalogueOrderResolver.stableFallbackHash(''), 0x811C9DC5);
    });

    test('התנגשות גיבוב אינה מייצרת סדר כפול', () {
      final resolver = CatalogueOrderResolver({'id:1': 0});
      final orders = {
        for (var i = 0; i < 500; i++) resolver.orderFor('uid:$i'),
      };

      expect(orders, hasLength(500));
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
