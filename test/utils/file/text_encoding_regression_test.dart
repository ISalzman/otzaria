// רגרסיה מול המימוש הקודם (§48, §52).
//
// המימוש הקודם משוכפל כאן במלואו, ומורץ על אותו קורפוס. הכלל: כל קובץ
// שהמימוש הקודם פענח **נכון** חייב לצאת מהחדש בדיוק אותו דבר. הקבצים
// שהמימוש הקודם טעה בהם מתועדים למטה אחד לאחד, כדי שהשינוי יהיה מכוון ולא
// תופעת לוואי.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/text_encoding.dart';

import '../../../tool/generate_text_encoding_fixtures.dart';

// ===========================================================================
// המימוש הקודם, כפי שהיה לפני ההרחבה
// ===========================================================================

String previousDecodeTextBytesSmart(Uint8List bytes) {
  if (bytes.isEmpty) return '';

  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _previousDecodeUtf16(bytes, offset: 2, littleEndian: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _previousDecodeUtf16(bytes, offset: 2, littleEndian: false);
  }

  final utf16 = _previousTryDecodeUtf16WithoutBom(bytes);
  if (utf16 != null) return utf16;

  try {
    return utf8.decode(bytes);
  } on FormatException {
    // לא UTF-8 חוקי — ממשיכים לזיהוי הבא.
  }

  return _previousDecodeWindows1255(bytes);
}

String? _previousTryDecodeUtf16WithoutBom(Uint8List bytes) {
  if (bytes.length < 4) return null;
  final evenLength = bytes.length.isEven ? bytes.length : bytes.length - 1;
  final sampleLen = evenLength < 4096 ? evenLength : 4096;
  var littleEndianScore = 0;
  var bigEndianScore = 0;
  for (var i = 0; i + 1 < sampleLen; i += 2) {
    final littleEndian = bytes[i] | (bytes[i + 1] << 8);
    final bigEndian = (bytes[i] << 8) | bytes[i + 1];
    if (_previousIsLikelyTextCodeUnit(littleEndian)) littleEndianScore++;
    if (_previousIsLikelyTextCodeUnit(bigEndian)) bigEndianScore++;
  }

  final pairs = sampleLen ~/ 2;
  if (littleEndianScore * 4 >= pairs * 3 &&
      littleEndianScore > bigEndianScore * 2) {
    return _previousDecodeUtf16(bytes, offset: 0, littleEndian: true);
  }
  if (bigEndianScore * 4 >= pairs * 3 &&
      bigEndianScore > littleEndianScore * 2) {
    return _previousDecodeUtf16(bytes, offset: 0, littleEndian: false);
  }
  return null;
}

bool _previousIsLikelyTextCodeUnit(int unit) {
  return unit == 0x09 ||
      unit == 0x0A ||
      unit == 0x0D ||
      (unit >= 0x20 && unit <= 0x7E) ||
      (unit >= 0x00A0 && unit <= 0x05FF) ||
      (unit >= 0x2000 && unit <= 0x206F);
}

String _previousDecodeUtf16(
  Uint8List bytes, {
  required int offset,
  required bool littleEndian,
}) {
  final codeUnits = <int>[];
  for (var i = offset; i + 1 < bytes.length; i += 2) {
    codeUnits.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(codeUnits);
}

/// הטבלה מוקפאת כאן במתכוון, ואינה נגזרת מהמוצר: קו-בסיס שנשען על טבלת
/// הייצור היה זז יחד איתה, ורגרסיה בטבלה לא הייתה נראית בהשוואה.
String _previousDecodeWindows1255(Uint8List bytes) => String.fromCharCodes([
  for (final byte in bytes)
    if (byte < 0x80) byte else _previousCp1255High[byte - 0x80],
]);

const List<int> _previousCp1255High = [
  0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, // 0x80
  0x02C6, 0x2030, 0xFFFD, 0x2039, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // 0x88
  0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, // 0x90
  0x02DC, 0x2122, 0xFFFD, 0x203A, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // 0x98
  0x00A0, 0x00A1, 0x00A2, 0x00A3, 0x20AA, 0x00A5, 0x00A6, 0x00A7, // 0xA0
  0x00A8, 0x00A9, 0x00D7, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF, // 0xA8
  0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7, // 0xB0
  0x00B8, 0x00B9, 0x00F7, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x00BF, // 0xB8
  0x05B0, 0x05B1, 0x05B2, 0x05B3, 0x05B4, 0x05B5, 0x05B6, 0x05B7, // 0xC0
  0x05B8, 0x05B9, 0x05BA, 0x05BB, 0x05BC, 0x05BD, 0x05BE, 0x05BF, // 0xC8
  0x05C0, 0x05C1, 0x05C2, 0x05C3, 0x05F0, 0x05F1, 0x05F2, 0x05F3, // 0xD0
  0x05F4, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // 0xD8
  0x05D0, 0x05D1, 0x05D2, 0x05D3, 0x05D4, 0x05D5, 0x05D6, 0x05D7, // 0xE0
  0x05D8, 0x05D9, 0x05DA, 0x05DB, 0x05DC, 0x05DD, 0x05DE, 0x05DF, // 0xE8
  0x05E0, 0x05E1, 0x05E2, 0x05E3, 0x05E4, 0x05E5, 0x05E6, 0x05E7, // 0xF0
  0x05E8, 0x05E9, 0x05EA, 0xFFFD, 0xFFFD, 0x200E, 0x200F, 0xFFFD, // 0xF8
];

// ===========================================================================

void main() {
  final directory = Directory.systemTemp.createTempSync('otzaria_regression_');
  final fixtures = generateTextEncodingFixtures(directory);

  tearDownAll(() {
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // תיקיית temp שנשארה תפוסה אינה כשל של המוצר.
    }
  });

  Uint8List bytesOf(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name').readAsBytesSync();

  /// הקבצים שבהם הפלט **שונה** בכוונה מהמימוש הקודם, והנימוק לכל אחד.
  const intentionalDifferences = {
    'utf8_looks_like_utf16.txt': 'UTF-8 חוקי נחטף בידי היוריסטיקת UTF-16 (§53)',
    'utf8_bom_invalid_payload.txt':
        'BOM עם מצע פגום הוחלף בשקט ב-U+FFFD (§12, §54)',
    'utf8_truncated_tail.txt': 'זנב קטוע פורש כ-Windows-1255 במקום להיחתך',
    'utf32le_bom.txt': 'UTF-32LE נקרא כ-UTF-16LE עם בתי אפס (§10)',
    'utf32be_bom.txt': 'UTF-32BE לא היה נתמך',
    'utf32le_no_bom.txt': 'UTF-32LE בלי BOM לא היה נתמך',
    'utf32be_no_bom.txt': 'UTF-32BE בלי BOM לא היה נתמך',
    'utf32le_bom_truncated.txt': 'UTF-32 לא היה נתמך',
    'cp862_letters.txt': 'CP862 פורש כ-Windows-1255 (§30)',
    'cp862_box_drawing.txt': 'CP862 פורש כ-Windows-1255',
    'iso8859_8_double_low_line.txt': 'הבית 0xDF פורש כ-U+FFFD (§21)',
    'utf8_invalid_middle.txt': 'בתים פגומים פורשו כ-Windows-1255',
    'utf8_invalid_not_truncated_tail.txt':
        'רצף פגום בסוף פורש כ-Windows-1255 על כל הקובץ',
  };

  test('כל קובץ שהמימוש הקודם פענח נכון יוצא זהה מהחדש', () {
    final unchanged = <String>[];
    final changed = <String>[];
    for (final fixture in fixtures) {
      if (fixture.expectedText == null) continue;
      final bytes = bytesOf(fixture.file);
      final previous = previousDecodeTextBytesSmart(bytes);
      final current = decodeTextBytesSmart(bytes);
      if (previous == fixture.expectedText) {
        expect(
          current,
          previous,
          reason: '${fixture.file}: המימוש הקודם פענח נכון, והחדש שינה את הפלט',
        );
        unchanged.add(fixture.file);
      } else if (previous != current) {
        changed.add(fixture.file);
      }
    }
    expect(unchanged, isNotEmpty);
    stdout.writeln(
      'רגרסיה: ${unchanged.length} קבצים ללא שינוי, '
      '${changed.length} קבצים שהפלט בהם השתנה בכוונה',
    );
  });

  test('רשימת השינויים המכוונים זהה לרשימת השינויים בפועל', () {
    // שוויון קבוצות ולשני הכיוונים: שינוי שלא תועד ייפול כאן, וגם ערך תיעוד
    // שהתיישן.
    final changed = {
      for (final fixture in fixtures)
        if (previousDecodeTextBytesSmart(bytesOf(fixture.file)) !=
            decodeTextBytesSmart(bytesOf(fixture.file)))
          fixture.file,
    };
    expect(intentionalDifferences.keys.toSet(), changed);
  });

  test('המימוש החדש מפענח נכון יותר קבצים מהקודם', () {
    var previousCorrect = 0;
    var currentCorrect = 0;
    var total = 0;
    for (final fixture in fixtures) {
      if (fixture.expectedText == null) continue;
      total++;
      final bytes = bytesOf(fixture.file);
      if (previousDecodeTextBytesSmart(bytes) == fixture.expectedText) {
        previousCorrect++;
      }
      if (decodeTextBytesSmart(bytes) == fixture.expectedText) {
        currentCorrect++;
      }
    }
    stdout.writeln(
      'נכונות על הקורפוס: קודם $previousCorrect/$total, '
      'חדש $currentCorrect/$total',
    );
    expect(currentCorrect, total);
    expect(currentCorrect, greaterThan(previousCorrect));
  });

  group('השינויים המכוונים, אחד לאחד', () {
    test('UTF-8 חוקי שנראה UTF-16: הקודם החזיר ג׳יבריש (§53)', () {
      final bytes = bytesOf('utf8_looks_like_utf16.txt');
      expect(previousDecodeTextBytesSmart(bytes), isNot(utf8.decode(bytes)));
      expect(decodeTextBytesSmart(bytes), utf8.decode(bytes));
    });

    test('BOM עם מצע פגום: הקודם ייצר תווי החלפה שקטים (§54)', () {
      final bytes = bytesOf('utf8_bom_invalid_payload.txt');
      expect(previousDecodeTextBytesSmart(bytes), contains('�'));
      final result = decodeTextBytesSmartDetailed(bytes);
      expect(result.text.contains('�'), isFalse);
      expect(result.lowConfidence, isTrue);
    });

    test('CP862: הקודם פירש עברית DOS כ-Windows-1255 (§30)', () {
      final bytes = bytesOf('cp862_letters.txt');
      expect(previousDecodeTextBytesSmart(bytes), isNot(contains('מאימתי')));
      expect(decodeTextBytesSmart(bytes), contains('מאימתי'));
    });

    test('UTF-32 עם BOM: הקודם קרא אותו כ-UTF-16 עם בתי אפס (§10)', () {
      final bytes = bytesOf('utf32le_bom.txt');
      expect(previousDecodeTextBytesSmart(bytes), contains(' '));
      expect(decodeTextBytesSmart(bytes).contains(' '), isFalse);
    });

    test('ISO-8859-8: הבית 0xDF היה U+FFFD (§21)', () {
      final bytes = bytesOf('iso8859_8_double_low_line.txt');
      expect(previousDecodeTextBytesSmart(bytes), contains('�'));
      expect(decodeTextBytesSmart(bytes), contains('‗'));
    });

    test('זנב UTF-8 קטוע: הקודם נפל ל-Windows-1255 על כל הקובץ', () {
      final bytes = bytesOf('utf8_truncated_tail.txt');
      expect(previousDecodeTextBytesSmart(bytes), isNot('שלום עולם '));
      expect(decodeTextBytesSmart(bytes), 'שלום עולם ');
    });

    test('כתב שאינו עברי או לטיני נשמר — קירילית ויוונית ב-UTF-16', () {
      // המימוש הקודם סמך על טווח יחידות רחב, ולכן פענח את הקבצים האלה נכון;
      // ההרחבה הייתה מפילה אותם אל הזיהוי של קידודי העברית.
      for (final name in [
        'utf16le_no_bom_cyrillic.txt',
        'utf16be_no_bom_greek.txt',
      ]) {
        final bytes = bytesOf(name);
        expect(
          decodeTextBytesSmart(bytes),
          previousDecodeTextBytesSmart(bytes),
          reason: '$name: פלט שכבר היה תקין השתנה',
        );
      }
    });
  });
}
