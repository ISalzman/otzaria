import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/view/tantivy_full_text_search.dart';

void main() {
  group('shouldShowFacetFilterBanner', () {
    test('אין שאילתה → אין באנר', () {
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: '',
          searchScopeFacets: const ['/תנ"ך'],
          currentFacets: const ['/תנ"ך'],
        ),
        isFalse,
      );
    });

    test('ברירת המחדל ["/"] מול ["/"] → אין באנר', () {
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const ['/'],
          currentFacets: const ['/'],
        ),
        isFalse,
      );
    });

    test('["/"] מול [] (שניהם = כל הספרייה) → אין באנר (רגרסיית #6)', () {
      // לפני התיקון, השוואת האורכים הלא-מנורמלת (1 != 0) הציגה באנר מיותר.
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const ['/'],
          currentFacets: const [],
        ),
        isFalse,
      );
      // וגם בכיוון ההפוך
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const [],
          currentFacets: const ['/'],
        ),
        isFalse,
      );
    });

    test('שני המערכים ריקים → אין באנר', () {
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const [],
          currentFacets: const [],
        ),
        isFalse,
      );
    });

    test('טווח מוגבל לקטגוריה אחת → באנר מוצג', () {
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const ['/תנ"ך'],
          currentFacets: const ['/תנ"ך'],
        ),
        isTrue,
      );
    });

    test('הטווח הוא כל הספרייה אך הסינון הנוכחי מצומצם → באנר מוצג', () {
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const ['/'],
          currentFacets: const ['/תנ"ך'],
        ),
        isTrue,
      );
    });

    test('סינון נוכחי שונה מהטווח (אותו אורך, ערך אחר) → באנר מוצג', () {
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const ['/תנ"ך'],
          currentFacets: const ['/משנה'],
        ),
        isTrue,
      );
    });

    test('סינון נוכחי תת-קבוצה של הטווח → באנר מוצג', () {
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const ['/תנ"ך', '/משנה'],
          currentFacets: const ['/תנ"ך'],
        ),
        isTrue,
      );
    });

    test('חיפוש מוגבל יציב (scope == current, שתיהן קטגוריות) → באנר מוצג', () {
      // מקרה שבו הנוסחה השגויה שהוצעה בסקירה (השוואת scope מול current)
      // הייתה מחזירה false בטעות — החיפוש מוגבל ולכן הבאנר חייב להופיע.
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const ['/תנ"ך', '/משנה'],
          currentFacets: const ['/משנה', '/תנ"ך'],
        ),
        isTrue,
      );
    });

    test('פאסט שורש "/" מנורמל החוצה אך קטגוריה אמיתית עדיין מציגה באנר', () {
      // ['/', '/תנ"ך'] → אחרי נרמול {'/תנ"ך'} → החיפוש מוגבל → באנר.
      expect(
        shouldShowFacetFilterBanner(
          searchQuery: 'דבר',
          searchScopeFacets: const ['/', '/תנ"ך'],
          currentFacets: const ['/תנ"ך'],
        ),
        isTrue,
      );
    });
  });
}
