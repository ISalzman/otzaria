/// רשומה מוכנה לפתיחה של מפרש בודד עבור [DbReferenceResult] מסוים.
///
/// נוצרת מראש בעת טעינת רשימת המפרשים, כך שהקליק על מפרש בתפריט יוכל לפתוח
/// אותו ישירות ללא שאילתות DB.
class DbCommentatorEntry {
  /// שם ספר המפרש (כפי שמופיע ב-`book.title`).
  final String title;

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
    required this.targetSegment,
  });

  @override
  bool operator ==(Object other) =>
      other is DbCommentatorEntry &&
      other.title == title &&
      other.targetSegment == targetSegment;

  @override
  int get hashCode => Object.hash(title, targetSegment);

  @override
  String toString() => 'DbCommentatorEntry($title @ $targetSegment)';
}
