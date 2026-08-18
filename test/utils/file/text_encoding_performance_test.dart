// יעדי הביצועים של הזיהוי (§44–§46).
//
// המדידות רצות ב-debug, ולכן התקרות רחבות בכוונה — היעד המספרי שבמפרט
// (20ms על 128KB) הוא ל-release. מה שהבדיקה שומרת עליו הוא הסדר גודל:
// שהזיהוי חסום בגודל הדגימה ולא בגודל הקובץ, שאין פענוח מלא כפול, ושה-import
// לא נעשה איטי פי כמה מהמימוש הקודם.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/text_encoding.dart';

import '../../../tool/generate_text_encoding_fixtures.dart';
import 'text_encoding_regression_test.dart' show previousDecodeTextBytesSmart;

/// זמן החציון של [runs] הרצות במיקרו-שניות — חציון ולא ממוצע, כדי ש-GC
/// אקראי לא יקבע את התוצאה.
int _medianMicros(int runs, void Function() action) {
  final samples = <int>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    action();
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2];
}

String _kb(int bytes) => '${bytes ~/ 1024}KB';

void main() {
  // 700 פסקאות כדי שגם הגרסה החד-בייטית תעבור את תקרת הדגימה של 128KB.
  final bookText = largeHebrewBook(paragraphs: 700);
  final cp1255Book = encodeLegacy(bookText, TextEncoding.windows1255);
  final utf8Book = Uint8List.fromList(utf8.encode(bookText));
  final utf16Book = encodeUtf16(bookText, littleEndian: true, bom: true);

  setUpAll(() {
    // חימום: ההרצה הראשונה בכל מסלול משלמת על JIT ולא על האלגוריתם.
    for (final bytes in [cp1255Book, utf8Book, utf16Book]) {
      decodeTextBytesSmartDetailed(bytes);
      detectTextEncoding(bytes);
    }
  });

  test('קורפוס המדידה גדול מתקרת הדגימה', () {
    expect(cp1255Book.length, greaterThan(kDetectionSampleBytes));
    expect(utf8Book.length, greaterThan(kDetectionSampleBytes));
    expect(utf16Book.length, greaterThan(kDetectionSampleBytes));
  });

  test('זיהוי דגימה של 128KB — סדר גודל של מילישניות בודדות (§44)', () {
    final sample = Uint8List.sublistView(cp1255Book, 0, kDetectionSampleBytes);
    final micros = _medianMicros(20, () => detectTextEncoding(sample));
    stdout.writeln(
      'זיהוי דגימה של 128KB: $micros מיקרו-שניות (יעד release: 20,000)',
    );
    expect(micros, lessThan(150000));
  });

  test('הזיהוי חסום בגודל הדגימה ולא בגודל הקובץ (§42)', () {
    final huge = Uint8List(cp1255Book.length * 8);
    for (var i = 0; i < huge.length; i++) {
      huge[i] = cp1255Book[i % cp1255Book.length];
    }
    detectTextEncoding(huge);

    final small = _medianMicros(10, () => detectTextEncoding(cp1255Book));
    final large = _medianMicros(10, () => detectTextEncoding(huge));
    stdout.writeln(
      'זיהוי: ${_kb(cp1255Book.length)} = $small מיקרו-שניות, '
      '${_kb(huge.length)} = $large מיקרו-שניות',
    );
    expect(large, lessThan(small * 4 + 5000));
  });

  test('פענוח מלא אחד בלבד לכל קובץ (§42, §47)', () {
    // פענוח Windows-1255 ידוע מראש הוא הרצפה התיאורטית: מעבר אחד על כל בית.
    final floor = _medianMicros(
      10,
      () => decodeTextBytesWith(cp1255Book, TextEncoding.windows1255),
    );
    final full = _medianMicros(10, () => decodeTextBytesSmart(cp1255Book));
    stdout.writeln(
      'פענוח ${_kb(cp1255Book.length)}: ידוע מראש $floor מיקרו-שניות, '
      'עם זיהוי $full מיקרו-שניות',
    );
    expect(full, lessThan(floor * 3 + 5000));
  });

  test('תפוקת batch על 1,000 קבצים בקידודים מעורבים (§45, §72)', () {
    const files = 1000;
    const chunk = 48 * 1024;
    final sources = [utf8Book, cp1255Book, utf16Book];
    final batch = <Uint8List>[
      for (var i = 0; i < files; i++)
        Uint8List.sublistView(sources[i % sources.length], 0, chunk),
    ];

    final distribution = <TextEncoding, int>{};
    var lowConfidence = 0;
    var characters = 0;
    final watch = Stopwatch()..start();
    for (final bytes in batch) {
      final result = decodeTextBytesSmartDetailed(bytes);
      distribution.update(
        result.encoding,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      if (result.lowConfidence) lowConfidence++;
      characters += result.text.length;
    }
    final elapsed = watch.elapsedMilliseconds;
    final perSecond = (files / (elapsed / 1000)).toStringAsFixed(0);

    stdout.writeln(
      'batch: $files קבצים של 48KB ב-$elapsed מילישניות '
      '($perSecond קבצים לשניה), $characters תווים',
    );
    stdout.writeln(
      'התפלגות הזיהוי: '
      '${distribution.entries.map((e) => '${e.key.label}=${e.value}').join(', ')}'
      ' | ודאות נמוכה: $lowConfidence',
    );

    expect(lowConfidence, 0);
    expect(distribution.length, 3);
    expect(elapsed, lessThan(20000));
  });

  test('ההאטה מול המימוש הקודם נשארת בסדר גודל אחד (§46)', () {
    // הזיהוי החדש מנקד שלושה מועמדי legacy ושתי היוריסטיקות Unicode שהקודם
    // לא הכיר, ולכן האטה מסוימת מובנית; מה שנשמר הוא סדר הגודל.
    for (final entry in {
      'Windows-1255': cp1255Book,
      'UTF-8': utf8Book,
      'UTF-16LE+BOM': utf16Book,
    }.entries) {
      final previous = _medianMicros(
        10,
        () => previousDecodeTextBytesSmart(entry.value),
      );
      final current = _medianMicros(
        10,
        () => decodeTextBytesSmart(entry.value),
      );
      final ratio = (current / previous).toStringAsFixed(2);
      stdout.writeln(
        '${entry.key} (${_kb(entry.value.length)}): קודם $previous, '
        'חדש $current מיקרו-שניות, יחס $ratio',
      );
      expect(current, lessThan(previous * 3 + 10000));
    }
  });
}
