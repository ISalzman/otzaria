/// Result of a reference search from the database.
/// This class mirrors the structure of ReferenceSearchResult from search_engine
/// but is populated from the database instead of Tantivy.
class DbReferenceResult {
  /// The title of the book
  final String title;

  /// The full reference text (e.g., "בראשית פרק א")
  final String reference;

  /// The segment/line number in the book
  final num segment;

  /// Whether this is a PDF file
  final bool isPdf;

  /// The file path (for PDF files)
  final String filePath;

  /// סדר הספר בספרייה — ספר מוקדם יותר = ערך נמוך יותר = עולה קודם.
  /// מועתק מ-[ReferenceBookHit.orderIndex] בעת הבנייה.
  final double orderIndex;

  /// true = תוצאה ממבנה AltToc (כותרות-משנה: עליות, פרשות וכד').
  /// תוצאות כאלה מדורגות אחרי רמה 2 ולפני רמה 3 של ה-TOC הרגיל.
  final bool isAltToc;

  /// רמת ה-TOC של הערך (1 = שם ספר, 2 = כותרות בסיסיות, 3+ = כותרות פנימיות).
  /// עבור AltToc, הרמה מתייחסת לפנים מבנה ה-AltToc עצמו (לא לתוצאה הסופית בסדר).
  final int tocLevel;

  /// מזהה הספר ב-DB, נדרש לבניית נתיב הקטגוריה.
  /// ערך -1 = ספר PDF ממערכת הקבצים (לא ב-DB).
  final int bookId;

  /// נתיב הקטגוריה המלא (למשל "תנ"ך, תורה, בראשית").
  /// ריק אם לא נמצא.
  final String bookPath;

  /// מזהה השורה הגלובלי ב-`line` table של ה-DB (לשאילתות `link.sourceLineId`).
  /// 0 = לא ידוע / לא רלוונטי (למשל הפניה לספר עצמו או PDF).
  final int sourceLineId;

  /// true = תוצאה מ-user_books.db (ספרים אישיים).
  /// ה-[bookId] וה-[sourceLineId] שייכים ל-namespace נפרד ואינם תקפים מול
  /// ה-DB הראשי — אסור להריץ עליהם שאילתות `link` או `commentators`.
  final bool isUserBook;

  const DbReferenceResult({
    required this.title,
    required this.reference,
    required this.segment,
    this.isPdf = false,
    this.filePath = '',
    this.orderIndex = 0.0,
    this.isAltToc = false,
    this.tocLevel = 1,
    this.bookId = -1,
    this.bookPath = '',
    this.sourceLineId = 0,
    this.isUserBook = false,
  });

  @override
  String toString() =>
      'DbReferenceResult(title: $title, reference: $reference, segment: $segment, isPdf: $isPdf, isAltToc: $isAltToc, tocLevel: $tocLevel)';
}
