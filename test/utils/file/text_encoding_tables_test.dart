// נועץ את טבלאות המיפוי מול התקנים שהן מצהירות עליהן.
//
// הציפיות כאן כתובות ידנית מתוך המפרטים (WHATWG windows-1255, 8859-8.TXT,
// CP862.TXT) ולא נגזרות מהקוד — טבלה שתשתנה בטעות תיפול כאן, לא אצל משתמש
// שיקבל ספר ג'יבריש.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/text_encoding.dart';

String _decode(List<int> bytes, TextEncoding encoding) =>
    decodeTextBytesWith(Uint8List.fromList(bytes), encoding);

String _decodeByte(int byte, TextEncoding encoding) =>
    _decode([byte], encoding);

/// נקודת הקוד שאליה מתורגם בית בודד — לתווים שאינם נראים בקוד המקור.
int _codePoint(int byte, TextEncoding encoding) =>
    _decodeByte(byte, encoding).runes.first;

/// אלף עד תו בסדר נקודות הקוד — U+05D0..U+05EA.
final String _hebrewAlphabet = String.fromCharCodes([
  for (var codePoint = 0x05D0; codePoint <= 0x05EA; codePoint++) codePoint,
]);

void main() {
  group('Windows-1255', () {
    test('אותיות עבריות ב-0xE0–0xFA', () {
      final bytes = [for (var byte = 0xE0; byte <= 0xFA; byte++) byte];
      expect(_decode(bytes, TextEncoding.windows1255), _hebrewAlphabet);
    });

    test('ניקוד ב-0xC0–0xCF', () {
      final bytes = [for (var byte = 0xC0; byte <= 0xCF; byte++) byte];
      expect(
        _decode(bytes, TextEncoding.windows1255),
        String.fromCharCodes([
          for (var codePoint = 0x05B0; codePoint <= 0x05BF; codePoint++)
            codePoint,
        ]),
      );
    });

    test('פסק, שין-דוט, שין-שמאל וסוף פסוק ב-0xD0–0xD3', () {
      expect(_codePoint(0xD0, TextEncoding.windows1255), 0x05C0);
      expect(_codePoint(0xD1, TextEncoding.windows1255), 0x05C1);
      expect(_codePoint(0xD2, TextEncoding.windows1255), 0x05C2);
      expect(_codePoint(0xD3, TextEncoding.windows1255), 0x05C3);
    });

    test('ליגטורות יידיש, גרש וגרשיים ב-0xD4–0xD8', () {
      expect(_decodeByte(0xD4, TextEncoding.windows1255), 'װ');
      expect(_decodeByte(0xD5, TextEncoding.windows1255), 'ױ');
      expect(_decodeByte(0xD6, TextEncoding.windows1255), 'ײ');
      expect(_decodeByte(0xD7, TextEncoding.windows1255), '׳');
      expect(_decodeByte(0xD8, TextEncoding.windows1255), '״');
    });

    test('סימן שקל ב-0xA4 — הבית שמפריד מ-ISO-8859-8', () {
      expect(_decodeByte(0xA4, TextEncoding.windows1255), '₪');
      expect(_decodeByte(0xA4, TextEncoding.iso88598), '¤');
    });

    test('פיסוק טיפוגרפי ב-0x80–0x9F', () {
      expect(_decodeByte(0x80, TextEncoding.windows1255), '€');
      expect(_decodeByte(0x85, TextEncoding.windows1255), '…');
      expect(_decodeByte(0x91, TextEncoding.windows1255), '‘');
      expect(_decodeByte(0x92, TextEncoding.windows1255), '’');
      expect(_decodeByte(0x93, TextEncoding.windows1255), '“');
      expect(_decodeByte(0x94, TextEncoding.windows1255), '”');
      expect(_decodeByte(0x96, TextEncoding.windows1255), '–');
      expect(_decodeByte(0x97, TextEncoding.windows1255), '—');
    });

    test('סימני כיווניות ב-0xFD–0xFE', () {
      expect(_codePoint(0xFD, TextEncoding.windows1255), 0x200E);
      expect(_codePoint(0xFE, TextEncoding.windows1255), 0x200F);
    });

    test('בתים לא מוגדרים הופכים ל-U+FFFD', () {
      const undefinedBytes = [
        0x81,
        0x8A,
        0x8D,
        0x90,
        0x9D,
        0xD9,
        0xDF,
        0xFB,
        0xFF,
      ];
      for (final byte in undefinedBytes) {
        expect(
          _codePoint(byte, TextEncoding.windows1255),
          0xFFFD,
          reason: 'הבית 0x${byte.toRadixString(16)} אינו מוגדר ב-Windows-1255',
        );
      }
    });
  });

  group('ISO-8859-8', () {
    test('אותיות עבריות ב-0xE0–0xFA — זהות ל-Windows-1255', () {
      final bytes = [for (var byte = 0xE0; byte <= 0xFA; byte++) byte];
      expect(_decode(bytes, TextEncoding.iso88598), _hebrewAlphabet);
      expect(
        _decode(bytes, TextEncoding.iso88598),
        _decode(bytes, TextEncoding.windows1255),
      );
    });

    test('קו תחתי כפול ב-0xDF — הבית שמפריד מ-Windows-1255', () {
      expect(_decodeByte(0xDF, TextEncoding.iso88598), '‗');
      expect(_codePoint(0xDF, TextEncoding.windows1255), 0xFFFD);
    });

    test('כפל וחילוק ב-0xAA ו-0xBA', () {
      expect(_decodeByte(0xAA, TextEncoding.iso88598), '×');
      expect(_decodeByte(0xBA, TextEncoding.iso88598), '÷');
    });

    test('0x80–0x9F הם תווי בקרה C1', () {
      for (var byte = 0x80; byte <= 0x9F; byte++) {
        expect(_codePoint(byte, TextEncoding.iso88598), byte);
      }
    });

    test('טווח 0xC0–0xDE וכן 0xA1, 0xBF, 0xFB, 0xFC, 0xFF אינם מוגדרים', () {
      for (var byte = 0xC0; byte <= 0xDE; byte++) {
        expect(_codePoint(byte, TextEncoding.iso88598), 0xFFFD);
      }
      for (final byte in [0xA1, 0xBF, 0xFB, 0xFC, 0xFF]) {
        expect(_codePoint(byte, TextEncoding.iso88598), 0xFFFD);
      }
    });

    test('סימני כיווניות ב-0xFD–0xFE', () {
      expect(_codePoint(0xFD, TextEncoding.iso88598), 0x200E);
      expect(_codePoint(0xFE, TextEncoding.iso88598), 0x200F);
    });
  });

  group('CP862', () {
    test('אותיות עבריות ב-0x80–0x9A', () {
      final bytes = [for (var byte = 0x80; byte <= 0x9A; byte++) byte];
      expect(_decode(bytes, TextEncoding.cp862), _hebrewAlphabet);
    });

    test('סימני מטבע ב-0x9B–0x9F', () {
      expect(
        _decode([0x9B, 0x9C, 0x9D, 0x9E, 0x9F], TextEncoding.cp862),
        '¢£¥₧ƒ',
      );
    });

    test('הזנב זהה ל-CP437', () {
      expect(_decodeByte(0xA0, TextEncoding.cp862), 'á');
      expect(_decodeByte(0xAD, TextEncoding.cp862), '¡');
      expect(_decodeByte(0xB0, TextEncoding.cp862), '░');
      expect(_decodeByte(0xB3, TextEncoding.cp862), '│');
      expect(_decodeByte(0xC4, TextEncoding.cp862), '─');
      expect(_decodeByte(0xC8, TextEncoding.cp862), '╚');
      expect(_decodeByte(0xDB, TextEncoding.cp862), '█');
      expect(_decodeByte(0xE0, TextEncoding.cp862), 'α');
      expect(_decodeByte(0xE8, TextEncoding.cp862), 'Φ');
      expect(_decodeByte(0xF0, TextEncoding.cp862), '≡');
      expect(_decodeByte(0xF8, TextEncoding.cp862), '°');
      expect(_decodeByte(0xFE, TextEncoding.cp862), '■');
      expect(_codePoint(0xFF, TextEncoding.cp862), 0x00A0);
    });

    test('אין ב-CP862 בית לא מוגדר', () {
      for (var byte = 0x80; byte <= 0xFF; byte++) {
        expect(
          _codePoint(byte, TextEncoding.cp862),
          isNot(0xFFFD),
          reason: 'הבית 0x${byte.toRadixString(16)} חייב מיפוי ב-CP862',
        );
      }
    });

    test('ASCII נשאר ASCII בכל הקידודים הישנים', () {
      final ascii = [for (var byte = 0x20; byte < 0x7F; byte++) byte];
      final expected = String.fromCharCodes(ascii);
      for (final encoding in [
        TextEncoding.windows1255,
        TextEncoding.iso88598,
        TextEncoding.cp862,
      ]) {
        expect(_decode(ascii, encoding), expected);
      }
    });
  });

  group('decodeCodepageByte', () {
    test('דפי-קוד מוכרים', () {
      expect(decodeCodepageByte(0xE0, 1255), 0x05D0);
      expect(decodeCodepageByte(0xA4, 1255), 0x20AA);
      expect(decodeCodepageByte(0x80, 1252), 0x20AC);
      expect(decodeCodepageByte(0xE9, 1252), 0x00E9);
      expect(decodeCodepageByte(0x80, 862), 0x05D0);
      expect(decodeCodepageByte(0xE0, 28598), 0x05D0);
      expect(decodeCodepageByte(0xDF, 28598), 0x2017);
    });

    test('ASCII ודף-קוד לא מוכר', () {
      expect(decodeCodepageByte(0x41, 1255), 0x41);
      expect(decodeCodepageByte(0xE9, 99999), 0xE9);
    });
  });

  group('ניקוד המועמדים', () {
    test('ניקוד ההיסטוגרמה זהה לניקוד הטקסט המפוענח', () {
      final samples = <Uint8List>[
        Uint8List.fromList([0xF9, 0xEC, 0xE5, 0xED, 0x20, 0xE2, 0xE3, 0xE5]),
        Uint8List.fromList([for (var byte = 0; byte < 256; byte++) byte]),
        Uint8List.fromList([0x99, 0x8C, 0x85, 0x8D, 0x20, 0x41, 0x42]),
        Uint8List.fromList([0xC0, 0xC1, 0xC2, 0xD7, 0xD8, 0xA4]),
      ];
      for (final sample in samples) {
        for (final encoding in [
          TextEncoding.windows1255,
          TextEncoding.iso88598,
          TextEncoding.cp862,
        ]) {
          final histogramScore = scoreLegacyEncoding(sample, encoding).score;
          final textScore = scoreDecodedText(
            decodeTextBytesWith(sample, encoding),
          );
          expect(
            histogramScore,
            closeTo(textScore, 1e-9),
            reason: 'ניקוד ${encoding.label} על ${sample.length} בתים',
          );
        }
      }
    });

    test('עברית תקינה מנקדת גבוה, ובתים לא מוגדרים מנקדים נמוך', () {
      final hebrew = Uint8List.fromList([
        0xF9,
        0xEC,
        0xE5,
        0xED,
        0x20,
        0xE2,
        0xE3,
        0xE5,
        0xEC,
        0x2E,
      ]);
      expect(
        scoreLegacyEncoding(hebrew, TextEncoding.windows1255).score,
        greaterThan(0.95),
      );
      expect(
        scoreLegacyEncoding(hebrew, TextEncoding.cp862).score,
        lessThan(0.75),
      );

      final unmapped = Uint8List.fromList([0xD9, 0xDA, 0xDB, 0xDC, 0xDD]);
      expect(
        scoreLegacyEncoding(unmapped, TextEncoding.windows1255).score,
        lessThan(0.1),
      );
    });

    test('העדות הייחודית מסמנת רק בתים שקידוד אחד מסביר', () {
      // 0xC1 הוא ניקוד ב-Windows-1255, לא מוגדר ב-ISO-8859-8 ומסגרת ב-CP862.
      final niqqud = Uint8List.fromList([0xC1, 0xC2, 0xC3, 0xC4]);
      expect(
        scoreLegacyEncoding(niqqud, TextEncoding.windows1255).distinctiveBytes,
        4,
      );
      expect(
        scoreLegacyEncoding(niqqud, TextEncoding.cp862).distinctiveBytes,
        0,
      );

      // אותיות עבריות מוסברות בכל השלושה — אין בהן עדות ייחודית לאף אחד.
      final letters = Uint8List.fromList([0xE0, 0xE1, 0xE2]);
      for (final encoding in [
        TextEncoding.windows1255,
        TextEncoding.iso88598,
      ]) {
        expect(scoreLegacyEncoding(letters, encoding).distinctiveBytes, 0);
      }
    });

    test('scoreDecodedText מדרג טקסט עברי מעל ג׳יבריש', () {
      expect(scoreDecodedText('שלום עולם, ספר בראשית.'), greaterThan(0.95));
      expect(scoreDecodedText('Hello World 123'), greaterThan(0.95));
      expect(scoreDecodedText('���'), lessThan(0.1));
      expect(scoreDecodedText(''), 0.0);
    });
  });
}
