import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/document_conversion_exceptions.dart';
import 'package:otzaria/utils/file/document_format.dart';
import 'package:otzaria/utils/file/odt_to_otzaria.dart';
import 'package:otzaria/utils/file/zip_limits.dart';

/// חבילה זדונית מצהירה על פריסה עצומה מקובץ זעיר ("zip bomb"). הבדיקות כאן
/// מוודאות שהחסימה קורית על המטא-דאטה — לפני שהתוכן נקרא לזיכרון (§73).
void main() {
  /// רשומה שמצהירה על [declaredSize] פרוס אך מכילה [content] בלבד.
  ArchiveFile entry(String name, int declaredSize, List<int> content) =>
      ArchiveFile(name, declaredSize, content);

  group('מגבלות פריסה', () {
    test('חבילה תקינה עוברת', () {
      final archive = Archive()
        ..addFile(
          ArchiveFile('content.xml', 10, utf8.encode('<office/>')),
        );
      expect(
        () => assertSafeArchive(archive, format: DocumentFormat.odt),
        returnsNormally,
      );
    });

    test('יותר מדי רשומות נחסם', () {
      final archive = Archive();
      for (var i = 0; i <= ZipLimits.maxEntries; i++) {
        archive.addFile(ArchiveFile('f$i.xml', 1, const [0x41]));
      }
      expect(
        () => assertSafeArchive(archive, format: DocumentFormat.odt),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('רשומה בודדת גדולה מדי נחסמת', () {
      final archive = Archive()
        ..addFile(
          entry('huge.bin', ZipLimits.maxEntryBytes + 1, const [0x41]),
        );
      expect(
        () => assertSafeArchive(archive, format: DocumentFormat.odt),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('סך פריסה מצטבר מעל הסף נחסם', () {
      final archive = Archive();
      final chunk = ZipLimits.maxEntryBytes;
      // חמש רשומות בגודל המרבי חוצות יחד את סף החבילה.
      for (var i = 0; i < 5; i++) {
        archive.addFile(entry('f$i.bin', chunk, const [0x41]));
      }
      expect(
        () => assertSafeArchive(archive, format: DocumentFormat.odt),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('החריגה נושאת את הפורמט ואת נתיב הקובץ', () {
      final archive = Archive()
        ..addFile(
          entry('bomb.bin', ZipLimits.maxEntryBytes + 1, const [0x41]),
        );
      try {
        assertSafeArchive(
          archive,
          format: DocumentFormat.docx,
          path: 'C:/ספרים/זדוני.docx',
        );
        fail('הייתה אמורה להיזרק חריגה');
      } on CorruptedDocumentException catch (e) {
        expect(e.format, DocumentFormat.docx);
        expect(e.path, 'C:/ספרים/זדוני.docx');
        expect(e.toString(), contains('docx'));
      }
    });

    test('רשומה זעירה עם יחס דחיסה גבוה אינה נחסמת', () {
      // קובץ קטן מייצר יחס גבוה מטבעו ואינו מסוכן.
      final archive = Archive()
        ..addFile(entry('small.xml', 100000, const [0x41, 0x42]));
      expect(
        () => assertSafeArchive(archive, format: DocumentFormat.odt),
        returnsNormally,
      );
    });
  });

  group('אכיפה דרך הממיר', () {
    test('ODT עם רשומה מנופחת נדחה לפני קריאת התוכן', () {
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'mimetype',
            4,
            utf8.encode('application/vnd.oasis.opendocument.text'),
          ),
        )
        ..addFile(
          entry('content.xml', ZipLimits.maxEntryBytes + 1, const [0x41]),
        );
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(
        () => odtToText(bytes, 'זדוני'),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });
  });
}
