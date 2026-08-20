// אימות מול קורפוס חיצוני אמיתי (§50, §51, §71, §72).
//
// הקורפוס הזה נוצר בכלים חיצוניים (codecs של Python) ומכיל גם קבצי ספר
// אמיתיים מאוצריא באותו תוכן בחמישה קידודים — ולכן הוא עדות בלתי-תלויה
// בטבלאות המיפוי של המוצר.
//
// אם הקורפוס אינו על המכונה, הבדיקה מדלגת: היא מוסיפה ביטחון, אינה תנאי
// לבנייה. אפשר להצביע עליו בעזרת משתנה הסביבה
// `OTZARIA_TEXT_ENCODING_CORPUS`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/text_encoding.dart';

/// ברירת המחדל: התיקייה השכנה למאגר על מכונת הפיתוח.
const String _defaultCorpusPath =
    '../קידודי קבצים לצורך בדיקה באוצריא/text_encodings';

/// אותו ספר של אוצריא, שמור בחמישה קידודים — כולם חייבים לפענח לטקסט זהה.
const Map<String, TextEncoding> _sameBookInEveryEncoding = {
  'דוגמא טקסט אוצריא.txt': TextEncoding.utf8,
  '1דוגמא טקסט אוצריא.txt': TextEncoding.utf8,
  '2דוגמא טקסט אוצריא.txt': TextEncoding.utf16BE,
  '3דוגמא טקסט אוצריא.txt': TextEncoding.utf16LE,
  '4דוגמא טקסט אוצריא.txt': TextEncoding.windows1255,
};

/// שמות הקידודים שבמניפסט החיצוני, והקידוד שהזיהוי אמור לבחור.
///
/// ISO-8859-8 ממופה ל-Windows-1255 בכוונה: לטקסט עברי בלי בתים מבדילים שני
/// הקידודים מפיקים אותו טקסט בדיוק, ואז נבחר Windows-1255 כברירת מחדל (§29).
const Map<String, TextEncoding> _manifestEncodings = {
  'utf-8': TextEncoding.utf8,
  'ascii': TextEncoding.utf8,
  'utf-16le': TextEncoding.utf16LE,
  'utf-16be': TextEncoding.utf16BE,
  'utf-32le': TextEncoding.utf32LE,
  'utf-32be': TextEncoding.utf32BE,
  'windows1255': TextEncoding.windows1255,
  'iso8859_8': TextEncoding.windows1255,
  'cp862': TextEncoding.cp862,
};

void main() {
  final corpusPath =
      Platform.environment['OTZARIA_TEXT_ENCODING_CORPUS'] ??
      _defaultCorpusPath;
  final corpus = Directory(corpusPath);
  if (!corpus.existsSync()) {
    test('קורפוס חיצוני', () {
      stdout.writeln('הקורפוס החיצוני אינו זמין ($corpusPath) — מדלגים');
    }, skip: 'הקורפוס החיצוני אינו זמין על המכונה הזאת');
    return;
  }

  File fileIn(String name) =>
      File('${corpus.path}${Platform.pathSeparator}$name');

  group('ספר אוצריא אמיתי בכל הקידודים', () {
    final available = _sameBookInEveryEncoding.keys
        .where((name) => fileIn(name).existsSync())
        .toList();
    // קורפוס חלקי מדלג ולא נכשל: חסרון קובץ בתיקייה חיצונית אינו כשל של המוצר.
    final skip = available.length < _sameBookInEveryEncoding.length
        ? 'ספרי הדוגמה אינם בקורפוס שעל המכונה'
        : null;

    test('כל חמשת הקידודים מפענחים לאותו טקסט בדיוק', skip: skip, () {
      final texts = <String, String>{};
      for (final name in available) {
        final result = decodeTextBytesSmartDetailed(
          fileIn(name).readAsBytesSync(),
        );
        texts[name] = result.text;
        expect(
          result.encoding,
          _sameBookInEveryEncoding[name],
          reason:
              '$name זוהה כ-${result.encoding.label}\n'
              '${result.detectionReason}',
        );
        expect(result.lowConfidence, isFalse, reason: name);
      }
      final reference = texts[available.first]!;
      expect(reference, contains('עריכת ספר באוצריא'));
      expect(reference.length, greaterThan(30000));
      for (final entry in texts.entries) {
        expect(
          entry.value.length,
          reference.length,
          reason: '${entry.key}: אורך הטקסט שונה מהקובץ הראשון',
        );
        expect(entry.value, reference, reason: '${entry.key}: הטקסט שונה');
      }
    });
  });

  group('מניפסט הקורפוס החיצוני', () {
    final manifestFile = fileIn('manifest.json');
    if (!manifestFile.existsSync()) {
      test('manifest.json', () {}, skip: 'אין manifest.json בקורפוס');
      return;
    }
    final entries = (jsonDecode(manifestFile.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .where((entry) => fileIn(entry['filename'] as String).existsSync())
        .toList();

    test('המניפסט נטען ומכיל קבצים', () {
      expect(entries.length, greaterThan(20));
    });

    for (final entry in entries) {
      final name = entry['filename'] as String;
      final valid = entry['valid'] as bool;
      final expectedText = entry['expectedText'] as String?;
      final declared = entry['encoding'] as String;

      test('$name — ${entry['purpose']}', () {
        final bytes = fileIn(name).readAsBytesSync();
        final result = decodeTextBytesSmartDetailed(bytes);
        final report = describeTextEncodingDetection(bytes);

        if (valid && expectedText != null) {
          expect(result.text, expectedText, reason: 'טקסט שגוי.\n$report');
        }
        if (valid && _manifestEncodings.containsKey(declared)) {
          expect(
            result.encoding,
            _manifestEncodings[declared],
            reason: 'קידוד שגוי.\n$report',
          );
        }
        if (declared == 'unknown') {
          expect(
            result.lowConfidence,
            isTrue,
            reason: 'קלט שאינו טקסט קיבל ודאות גבוהה.\n$report',
          );
        }
        if (!valid) {
          expect(
            result.confidence,
            lessThan(1.0),
            reason: 'קובץ פגום קיבל ודאות מלאה.\n$report',
          );
        }
      });
    }
  });

  test('טלמטריה על כל הקורפוס (§71, §72)', () {
    final files = corpus
        .listSync()
        .whereType<File>()
        .where((file) => !file.path.endsWith('.json'))
        .where((file) => !file.path.endsWith('.py'))
        .toList();

    final distribution = <TextEncoding, int>{};
    final lowConfidenceFiles = <String>[];
    var bytesRead = 0;
    final watch = Stopwatch()..start();
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      bytesRead += bytes.length;
      final result = decodeTextBytesSmartDetailed(bytes);
      distribution.update(
        result.encoding,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (result.lowConfidence) {
        lowConfidenceFiles.add(
          '${file.uri.pathSegments.last} '
          '(${result.encoding.label} ${result.confidence.toStringAsFixed(2)})',
        );
      }
    }

    stdout.writeln(
      'קורפוס חיצוני: ${files.length} קבצים, $bytesRead בתים, '
      '${watch.elapsedMilliseconds} מילישניות',
    );
    for (final entry in distribution.entries) {
      stdout.writeln('  ${entry.key.label}: ${entry.value}');
    }
    stdout.writeln('  ודאות נמוכה: ${lowConfidenceFiles.length}');
    for (final name in lowConfidenceFiles) {
      stdout.writeln('    $name');
    }

    expect(files.length, greaterThan(20));
    expect(distribution.keys, contains(TextEncoding.utf8));
  });
}
