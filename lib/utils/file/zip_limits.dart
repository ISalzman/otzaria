import 'package:archive/archive.dart';
import 'package:otzaria/utils/file/document_conversion_exceptions.dart';
import 'package:otzaria/utils/file/document_format.dart';

/// מגבלות פריסה לחבילות ZIP (DOCX/DOCM/DOTX/DOTM/ODT/EPUB).
///
/// ארכיון זדוני או פגום יכול להצהיר על מאות אלפי רשומות או על פריסה של
/// ג'יגה-בייטים מקובץ של קילובייטים ("zip bomb"). הבדיקות כאן רצות על
/// המטא-דאטה בלבד — לפני שהתוכן נקרא לזיכרון.
class ZipLimits {
  /// מספר הרשומות המרבי בחבילה. מסמך אמיתי, כולל מאות תמונות, רחוק מכאן.
  static const int maxEntries = 20000;

  /// גודל פרוס מרבי לרשומה בודדת.
  static const int maxEntryBytes = 512 * 1024 * 1024;

  /// גודל פרוס מרבי לכל החבילה.
  static const int maxTotalBytes = 2 * 1024 * 1024 * 1024;

  /// יחס דחיסה מרבי (פרוס ÷ דחוס) לרשומה בודדת. טקסט XML נדחס היטב, ולכן
  /// הסף גבוה בכוונה — הוא נועד לתפוס רק ניפוח קיצוני.
  static const int maxCompressionRatio = 500;

  /// גודל רשומה דחוסה שמתחתיו יחס הדחיסה אינו נבדק. רשומה זעירה מייצרת
  /// יחס גבוה מטבעה ואינה מסוכנת.
  static const int ratioCheckMinCompressedBytes = 4096;
}

/// מוודא שהחבילה בטוחה לפריסה. זורק [CorruptedDocumentException] בהפרה.
///
/// יש לקרוא לפונקציה **לפני** גישה ל-`file.content` — הגישה היא שמפרסת את
/// הרשומה לזיכרון.
///
/// הבדיקות כאן מסתמכות על מה שהארכיון *מצהיר*; ארכיון זדוני יכול לשקר.
/// [readArchiveEntry] הוא שתופס את השקר.
void assertSafeArchive(
  Archive archive, {
  required DocumentFormat format,
  String? path,
}) {
  Never fail(String reason) => throw CorruptedDocumentException(
    path: path,
    format: format,
    cause: reason,
  );

  if (archive.length > ZipLimits.maxEntries) {
    fail('חבילה עם ${archive.length} רשומות (מעל ${ZipLimits.maxEntries})');
  }

  var total = 0;
  for (final file in archive) {
    if (!file.isFile) continue;

    final size = file.size;
    if (size > ZipLimits.maxEntryBytes) {
      fail('הרשומה "${file.name}" פרוסה ל-$size בתים');
    }

    total += size;
    if (total > ZipLimits.maxTotalBytes) {
      fail('גודל פרוס כולל מעל ${ZipLimits.maxTotalBytes} בתים');
    }

    final compressed = file.rawContent?.length ?? 0;
    if (compressed >= ZipLimits.ratioCheckMinCompressedBytes &&
        size ~/ compressed > ZipLimits.maxCompressionRatio) {
      fail('יחס דחיסה חשוד ברשומה "${file.name}" ($compressed → $size)');
    }
  }
}

/// קורא את תוכן הרשומה ומאמת את גודלו **בפועל**.
///
/// `file.size` הוא ה-uncompressed size שהארכיון הצהיר עליו, והפריסה אינה
/// חסומה לפיו. רשומה שהצהירה על 4KB יכולה להיפרס ל-40MB, ולעבור את כל
/// שלוש הבדיקות של [assertSafeArchive].
List<int> readArchiveEntry(
  ArchiveFile file, {
  required DocumentFormat format,
  String? path,
}) {
  final content = file.content;
  // ההשוואה מול ההצהרה עצמה ולא מול תקרה מוחלטת: בארכיון אמיתי השניים זהים,
  // ולכן חריגה כלשהי מעליה היא כבר עדות לשקר.
  if (content.length > file.size) {
    throw CorruptedDocumentException(
      path: path,
      format: format,
      cause:
          'הרשומה "${file.name}" הצהירה על ${file.size} בתים '
          'ונפרסה ל-${content.length}',
    );
  }
  return content;
}
