import 'package:otzaria/models/books.dart';

/// מפתח ספר אחיד לכל שכבות ה-provider.
///
/// הפורמט הוא: title + categoryId + fileType מנורמל.
class BookCompositeKey {
  final String title;
  final int categoryId;
  final String fileType;

  const BookCompositeKey({
    required this.title,
    required this.categoryId,
    required this.fileType,
  });

  factory BookCompositeKey.create({
    required String title,
    required int categoryId,
    String? fileType,
  }) {
    return BookCompositeKey(
      title: title,
      categoryId: categoryId,
      fileType: normalizeFileType(fileType),
    );
  }

  static BookCompositeKey? fromBook(Book book) {
    if (book.categoryId == null) return null;
    return BookCompositeKey.create(
      title: book.title,
      categoryId: book.categoryId!,
      fileType: book.fileType,
    );
  }

  static BookCompositeKey? tryParse(String key) {
    final parts = key.split('|');
    if (parts.length < 3) return null;
    final categoryId = int.tryParse(parts[1]);
    if (categoryId == null) return null;

    return BookCompositeKey.create(
      title: parts[0],
      categoryId: categoryId,
      fileType: parts[2],
    );
  }

  static String normalizeFileType(String? fileType) {
    final normalized = (fileType ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return 'txt';
    return normalized;
  }

  bool matchesTitle(String otherTitle) => title == otherTitle;

  bool matches(String otherTitle, {String? otherFileType}) {
    if (!matchesTitle(otherTitle)) return false;
    if (otherFileType == null) return true;
    return fileType == normalizeFileType(otherFileType);
  }

  String toStorageKey() => '$title|$categoryId|$fileType';

  @override
  String toString() => toStorageKey();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookCompositeKey &&
        other.title == title &&
        other.categoryId == categoryId &&
        other.fileType == fileType;
  }

  @override
  int get hashCode => Object.hash(title, categoryId, fileType);
}
