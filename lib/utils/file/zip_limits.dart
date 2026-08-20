import 'dart:typed_data';

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
  static const int maxEntryBytes = 64 * 1024 * 1024;

  /// גודל פרוס מרבי לכל החבילה.
  static const int maxTotalBytes = 256 * 1024 * 1024;

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

/// קורא רשומה בפריסה מוגבלת. הגבול נאכף תוך כדי הכתיבה של המפענח, לכן
/// מטא־דאטה כוזב אינו יכול לגרום להקצאה בלתי מוגבלת לפני שהשגיאה נזרקת.
List<int> readArchiveEntry(
  ArchiveFile file, {
  required DocumentFormat format,
  String? path,
}) {
  final output = _LimitedArchiveOutput(ZipLimits.maxEntryBytes);
  try {
    file.decompress(output);
  } on _ArchiveEntryLimitExceeded {
    throw CorruptedDocumentException(
      path: path,
      format: format,
      cause: 'הרשומה "${file.name}" חרגה מ-${ZipLimits.maxEntryBytes} בתים',
    );
  }
  if (output.length > file.size) {
    throw CorruptedDocumentException(
      path: path,
      format: format,
      cause:
          'הרשומה "${file.name}" הצהירה על ${file.size} בתים '
          'ונפרסה ל-${output.length}',
    );
  }
  return output.bytes;
}

class _ArchiveEntryLimitExceeded implements Exception {}

class _LimitedArchiveOutput extends OutputStream {
  _LimitedArchiveOutput(this._maxBytes)
    : super(byteOrder: ByteOrder.littleEndian);

  final int _maxBytes;
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  @override
  int get length => _length;
  int _length = 0;

  Uint8List get bytes => _bytes.takeBytes();

  void _reserve(int count) {
    if (count < 0 || _length + count > _maxBytes) {
      throw _ArchiveEntryLimitExceeded();
    }
    _length += count;
  }

  @override
  void clear() {
    _bytes.clear();
    _length = 0;
  }

  @override
  void flush() {}

  @override
  Uint8List subset(int start, [int? end]) {
    final all = _bytes.toBytes();
    return Uint8List.sublistView(all, start, end);
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    _bytes.addByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    _reserve(count);
    _bytes.add(bytes.sublist(0, count));
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      writeByte(stream.readByte());
    }
  }
}
