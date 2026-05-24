/// רשומה מוכנה לפתיחה של מפרש בודד עבור [DbReferenceResult] מסוים.
///
/// נוצרת מראש בעת טעינת רשימת המפרשים, כך שהקליק על מפרש בתפריט יוכל לפתוח
/// אותו ישירות ללא שאילתות DB.
class DbCommentatorEntry {
  /// שם ספר המפרש (כפי שמופיע ב-`book.title`).
  final String title;

  /// מזהה ספר המפרש ב-DB (`book.id`).
  ///
  /// נדרש לפתרון חד-משמעי של ה-`Book` כשיש שני ספרים בעלי אותה כותרת
  /// בעץ הספרייה (פתרון לפי title בלבד היה פותח את הראשון שנמצא בעץ,
  /// גם אם ה-link המקושר התכוון לאחר). `null` רק כשה-row של ה-DB לא
  /// כלל `targetBookId` (תאימות לאחור).
  final int? bookId;

  /// ה-`lineIndex` בספר המפרש שאליו יש לנווט, אם ידוע במדויק.
  ///
  /// `non-null` רק במסלול segment-level (`sourceLineId > 0`) — זה
  /// `MIN(lineIndex)` של הקישורים היוצאים מהשורה למפרש (=הקטע הראשון של
  /// המפרש על אותה שורה).
  ///
  /// `null` במסלול book-level fallback (אין `sourceLineId` או לא נמצאו
  /// קישורים segment-level). על הצרכן ליפול ל-best-effort, בדרך כלל
  /// `ref.segment.toInt()` בהנחת alignment שורה-שורה.
  ///
  /// חשוב: ה-`null` הוא קריטי לנכונות הקאש — הרשומה הזו נשמרת ב-cache
  /// לפי `bookId:sourceLineId` בלבד, ושני refs שונים עם אותו `bookId`
  /// וללא `sourceLineId` חולקים את אותו ערך מקאש. שמירת `ref.segment`
  /// כאן הייתה גורמת לכך שהקליק על תוצאה שנייה יפתח את ה-segment של
  /// התוצאה הראשונה.
  final int? targetSegment;

  const DbCommentatorEntry({
    required this.title,
    required this.bookId,
    required this.targetSegment,
  });

  @override
  bool operator ==(Object other) =>
      other is DbCommentatorEntry &&
      other.title == title &&
      other.bookId == bookId &&
      other.targetSegment == targetSegment;

  @override
  int get hashCode => Object.hash(title, bookId, targetSegment);

  @override
  String toString() => 'DbCommentatorEntry($title #$bookId @ $targetSegment)';
}
