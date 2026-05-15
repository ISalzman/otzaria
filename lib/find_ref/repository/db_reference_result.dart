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

  const DbReferenceResult({
    required this.title,
    required this.reference,
    required this.segment,
    this.isPdf = false,
    this.filePath = '',
    this.orderIndex = 0.0,
  });

  @override
  String toString() =>
      'DbReferenceResult(title: $title, reference: $reference, segment: $segment, isPdf: $isPdf)';
}
