import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/search/utils/facet_helper.dart';
import 'package:otzaria/search/utils/find_match_utils.dart';

/// תוצאת פענוח שאילתה עם תחביר צמצום: `מונח@שם`, כאשר השם הוא קטגוריה או ספר.
///
/// לדוגמה `שלום@תורה` → מחפש "שלום" בכל הקטגוריות שכותרתן "תורה"; ו-`שלום@בראשית`
/// → מחפש "שלום" בכל ספר או קטגוריה שכותרתם "בראשית" (בכל עומק בעץ).
class ParsedCategoryQuery {
  /// השאילתה ללא חלק הצמצום (מה שלפני ה-@).
  final String query;

  /// השם כפי שהוקלד (אחרי ה-@), או null אם לא הופיע `@` בשאילתה.
  final String? categoryName;

  /// נתיבי ה-facet של כל הקטגוריות והספרים שכותרתם תואמת (בכל עומק).
  /// null כאשר אין תחביר `@` בשאילתה.
  final List<String>? facets;

  const ParsedCategoryQuery({
    required this.query,
    this.categoryName,
    this.facets,
  });

  /// האם הופיע תחביר `@שם` (עם שם) בשאילתה.
  bool get hasCategoryToken => categoryName != null;

  /// האם נמצאה לפחות קטגוריה או ספר תואמים לשם שהוקלד.
  bool get categoryFound => facets != null && facets!.isNotEmpty;
}

/// מפענח שאילתה בתבנית `מונח@שם` (קטגוריה או ספר).
///
/// מחזיר את השאילתה הנקייה (ללא חלק הצמצום) ואת נתיבי ה-facet של כל הקטגוריות
/// והספרים שכותרתם תואמת לשם שאחרי ה-@ — בכל עומק בעץ הספרייה. אם יש כמה
/// התאמות באותו שם, כולן נכללות.
///
/// - אם אין `@` בשאילתה: [ParsedCategoryQuery.facets] יהיה null והשאילתה
///   תוחזר כמות שהיא.
/// - אם יש `@` אך השם ריק (למשל `שלום@`): מתעלמים מהתחביר ומחזירים
///   רק את החלק שלפני ה-@.
/// - הפיצול מתבצע על ה-@ האחרון, כך שהחלק שלפניו הוא השאילתה המלאה.
ParsedCategoryQuery parseCategoryQuery(String rawQuery, Library? library) {
  final atIndex = rawQuery.lastIndexOf('@');
  if (atIndex < 0) {
    return ParsedCategoryQuery(query: rawQuery);
  }

  final queryPart = rawQuery.substring(0, atIndex).trim();
  final categoryPart = rawQuery.substring(atIndex + 1).trim();

  // `@` ללא שם — מתעלמים מהתחביר ומחזירים את החלק שלפני ה-@.
  if (categoryPart.isEmpty) {
    return ParsedCategoryQuery(query: queryPart);
  }

  final normalizedName = normalizeFindText(categoryPart);
  final facets = <String>[];
  if (library != null && normalizedName.isNotEmpty) {
    for (final category in library.getAllCategories()) {
      if (normalizeFindText(category.title) == normalizedName) {
        facets.add(category.path);
      }
    }
    for (final book in library.getAllBooks()) {
      if (normalizeFindText(book.title) == normalizedName) {
        facets.add(
          FacetHelper.buildBookFacet(
            FacetHelper.resolveCategoryPath(book),
            book,
          ),
        );
      }
    }
  }

  return ParsedCategoryQuery(
    query: queryPart,
    categoryName: categoryPart,
    facets: facets,
  );
}
