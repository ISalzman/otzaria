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

  const DbReferenceResult({
    required this.title,
    required this.reference,
    required this.segment,
    this.isPdf = false,
    this.filePath = '',
    this.orderIndex = 0.0,
    this.isAltToc = false,
    this.tocLevel = 1,
  });

  @override
  String toString() =>
      'DbReferenceResult(title: $title, reference: $reference, segment: $segment, isPdf: $isPdf, isAltToc: $isAltToc, tocLevel: $tocLevel)';
}
