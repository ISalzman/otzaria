/// סיכום סיווג התוצאות של ספק חיפוש חיצוני (תוסף) עבור טאב חיפוש אחד.
///
/// נבנה ע"י מדור התוצאות החיצוני מתוך אינדקס התוצאות של הספק (ראו
/// PluginExternalSearchService), אחרי עידון מול קטלוג ההשוואות המקומי
/// ואימות מול עץ הספרייה. חלונית הסינון צורכת אותו כדי למזג את ספירות
/// הספרים לעץ הקטגוריות ולהציג את דלי "עוד מ<מקור>" לתוצאות שלא שויכו.
class ExternalSearchSummary {
  final String provider;

  /// שם המקור להצגה (resultsTitle של שורת התוסף), למשל 'היברובוקס'.
  final String sourceTitle;

  final int totalBooks;
  final int totalHits;

  /// ספירת ספרים לפי נתיב קטגוריה בספרייה (נתיבי עלים — בלי אבות; המיזוג
  /// לעץ מוסיף את האבות).
  final Map<String, int> categoryBookCounts;

  /// ספרים שלא שויכו לקטגוריה קיימת — מוצגים תחת [otherCategoryTitle].
  final int otherBooks;

  const ExternalSearchSummary({
    required this.provider,
    required this.sourceTitle,
    required this.totalBooks,
    required this.totalHits,
    required this.categoryBookCounts,
    required this.otherBooks,
  });

  String get otherCategoryTitle => 'עוד מ$sourceTitle';

  /// ה-facet הסינתטי של הדלי בעץ. אינו קיים במנוע — בחירתו מחזירה משם
  /// 0 תוצאות, והמדור החיצוני מציג את הספרים הלא-משויכים.
  String get otherCategoryFacet => '/$otherCategoryTitle';
}
