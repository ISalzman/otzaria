// בדיקות תכונה (property tests) על המפענח.
//
// הקורפוס בודק מקרים שנבחרו ביד; כאן נבדקות תכונות שחייבות להתקיים על **כל**
// קלט: שהפענוח אינו זורק, שהוא דטרמיניסטי, שהזיהוי לבדו מסכים עם הפענוח
// המלא, ושטקסט שקודד בקידוד נתמך חוזר ממנו תו-בתו.
//
// הטקסטים המוגרלים הם טקסט של ספר עברי (אותיות, ניקוד, פיסוק, ASCII) ולא רעש
// אחיד: זו האוכלוסייה שהמפענח מכויל אליה, ועליה החוזה שלו חל. הגרלה עם seed
// קבוע — כשל חייב להיות משוחזר.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/text_encoding.dart';

import '../../../tool/generate_text_encoding_fixtures.dart';

/// מגריל טקסט שנראה כמו ספר עברי: אותיות שולטות, ופיסוק, ספרות, ASCII וניקוד
/// בשיעורים סבירים.
String randomHebrewText(Random random, int length, {bool withNiqqud = false}) {
  const hebrewLetters = 'אבגדהוזחטיכךלמםנןסעפףצץקרשת';
  const punctuation = ',.:;()[]"\'-!? ';
  const ascii =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const niqqud = 'ְֱִֵַָֹּ';

  final buffer = StringBuffer();
  while (buffer.length < length) {
    final roll = random.nextInt(100);
    if (roll < 55) {
      buffer.write(hebrewLetters[random.nextInt(hebrewLetters.length)]);
      if (withNiqqud && random.nextInt(4) == 0) {
        buffer.write(niqqud[random.nextInt(niqqud.length)]);
      }
    } else if (roll < 70) {
      buffer.write(' ');
    } else if (roll < 82) {
      buffer.write(punctuation[random.nextInt(punctuation.length)]);
    } else if (roll < 94) {
      buffer.write(ascii[random.nextInt(ascii.length)]);
    } else {
      buffer.write('\n');
    }
  }
  return buffer.toString();
}

/// האם [encoding] מכיל את כל תווי [text].
bool canEncode(String text, TextEncoding encoding) {
  final table = legacyEncoderFor(encoding);
  return text.runes.every(table.containsKey);
}

Uint8List encodeWith(
  String text,
  TextEncoding encoding, {
  bool bom = false,
}) => switch (encoding) {
  TextEncoding.utf8 => Uint8List.fromList([
    if (bom) ...[0xEF, 0xBB, 0xBF],
    ...utf8.encode(text),
  ]),
  TextEncoding.utf16LE => encodeUtf16(text, littleEndian: true, bom: bom),
  TextEncoding.utf16BE => encodeUtf16(text, littleEndian: false, bom: bom),
  TextEncoding.utf32LE => encodeUtf32(text, littleEndian: true, bom: bom),
  TextEncoding.utf32BE => encodeUtf32(text, littleEndian: false, bom: bom),
  _ => encodeLegacy(text, encoding),
};

void main() {
  group('תכונות על קלט מוגרל', () {
    test('פענוח לעולם אינו זורק, וה-confidence תמיד בטווח', () {
      final random = Random(20260818);
      for (var iteration = 0; iteration < 2000; iteration++) {
        final length = random.nextInt(512);
        final bytes = Uint8List.fromList([
          for (var i = 0; i < length; i++) random.nextInt(256),
        ]);

        final result = decodeTextBytesSmartDetailed(bytes);
        expect(result.confidence, inInclusiveRange(0.0, 1.0));
        expect(result.detectionReason, isNotEmpty);
        expect(decodeTextBytesSmart(bytes), result.text);
        // אף קידוד נתמך אינו מייצר יותר יחידות קוד מבתים — פענוח אינו ממציא
        // תווים, גם לא מקלט פגום.
        expect(result.text.length, lessThanOrEqualTo(bytes.length));
      }
    });

    test('שיבוש בתים בודדים בקובץ תקין אינו מפיל ואינו ממציא תווים', () {
      // ההתפלגות הזאת שונה מרעש אחיד: קובץ תקין ברובו עם קלקול מקומי — הצורה
      // של קובץ שנפגע בהעתקה או בהורדה שנקטעה.
      final random = Random(1290);
      for (var iteration = 0; iteration < 300; iteration++) {
        final text = randomHebrewText(random, 80 + random.nextInt(200));
        final encoding =
            TextEncoding.values[random.nextInt(TextEncoding.values.length)];
        if (encoding.isLegacyHebrew && !canEncode(text, encoding)) continue;
        final bytes = Uint8List.fromList(
          encodeWith(text, encoding, bom: random.nextBool()),
        );
        for (var flip = 0; flip < 1 + random.nextInt(3); flip++) {
          bytes[random.nextInt(bytes.length)] = random.nextInt(256);
        }

        final result = decodeTextBytesSmartDetailed(bytes);
        expect(result.confidence, inInclusiveRange(0.0, 1.0));
        expect(result.text.length, lessThanOrEqualTo(bytes.length));
        expect(decodeTextBytesSmart(bytes), result.text);
        expect(detectTextEncoding(bytes).encoding, result.encoding);
      }
    });

    test('הזיהוי דטרמיניסטי — אותם בתים, אותה תשובה', () {
      final random = Random(7);
      for (var iteration = 0; iteration < 500; iteration++) {
        final bytes = Uint8List.fromList([
          for (var i = 0; i < random.nextInt(300); i++) random.nextInt(256),
        ]);
        final first = decodeTextBytesSmartDetailed(bytes);
        final second = decodeTextBytesSmartDetailed(bytes);
        expect(second.encoding, first.encoding);
        expect(second.confidence, first.confidence);
        expect(second.text, first.text);
        expect(second.detectionReason, first.detectionReason);
      }
    });

    test('הזיהוי לבדו מסכים עם הפענוח המלא על כל קלט', () {
      // שני מסלולי ה-UTF-8 (אימות בלבד ופענוח קפדני כאימות) חייבים להסכים;
      // קלט מוגרל הוא הדרך למצוא את הבית שבו הם נחלקים.
      final random = Random(1948);
      for (var iteration = 0; iteration < 1500; iteration++) {
        final length = random.nextInt(64);
        final bytes = Uint8List.fromList([
          for (var i = 0; i < length; i++)
            // הטיה כלפי בתי UTF-8 חלקיים: שם עובר הגבול בין המסלולים.
            random.nextBool() ? random.nextInt(256) : 0xC0 + random.nextInt(64),
        ]);
        final detection = detectTextEncoding(bytes);
        final decoded = decodeTextBytesSmartDetailed(bytes);
        expect(decoded.encoding, detection.encoding, reason: '$bytes');
        expect(decoded.confidence, detection.confidence, reason: '$bytes');
        expect(decoded.detectionReason, detection.reason, reason: '$bytes');
        expect(decoded.hadBom, detection.hadBom, reason: '$bytes');
        expect(
          decoded.candidateScores,
          detection.candidateScores,
          reason: '$bytes',
        );
        // הטקסט חייב להיות פענוח הטווח שהזיהוי מתאר — כך נבדקים גם
        // `bomLength` וגם `validPrefixLength`.
        expect(
          decoded.text,
          decodeTextBytesWith(
            Uint8List.sublistView(
              bytes,
              detection.bomLength,
              detection.validPrefixLength ?? bytes.length,
            ),
            detection.encoding,
          ),
          reason: '$bytes',
        );
      }
    });
  });

  group('סבב שלם: קידוד → זיהוי → פענוח', () {
    test('טקסט עברי חוזר תו-בתו מכל קידוד שמייצג אותו', () {
      final random = Random(5776);
      final unicodeEncodings = [
        TextEncoding.utf8,
        TextEncoding.utf16LE,
        TextEncoding.utf16BE,
        TextEncoding.utf32LE,
        TextEncoding.utf32BE,
      ];
      final legacyEncodings = [
        TextEncoding.windows1255,
        TextEncoding.iso88598,
        TextEncoding.cp862,
      ];

      for (var iteration = 0; iteration < 120; iteration++) {
        final withNiqqud = iteration.isEven;
        final text = randomHebrewText(
          random,
          300 + random.nextInt(900),
          withNiqqud: withNiqqud,
        );

        for (final encoding in unicodeEncodings) {
          for (final bom in [false, true]) {
            final bytes = encodeWith(text, encoding, bom: bom);
            final result = decodeTextBytesSmartDetailed(bytes);
            expect(
              result.encoding,
              encoding,
              reason: 'קידוד שגוי ל-${encoding.label} (BOM=$bom)',
            );
            expect(
              result.text,
              text,
              reason: 'הטקסט השתנה ב-${encoding.label} (BOM=$bom)',
            );
            expect(result.hadBom, bom);
            expect(result.lowConfidence, isFalse);
          }
        }

        for (final encoding in legacyEncodings) {
          if (!canEncode(text, encoding)) continue;
          final bytes = encodeWith(text, encoding);
          final result = decodeTextBytesSmartDetailed(bytes);
          expect(
            result.text,
            text,
            reason: 'הטקסט השתנה ב-${encoding.label}',
          );
          expect(result.encoding.isLegacyHebrew, isTrue);
          expect(result.lowConfidence, isFalse);
          expect(result.text.contains('�'), isFalse);
        }
      }
    });

    test('גם טקסט קצר חוזר תו-בתו, גם כשהוודאות בו נמוכה', () {
      // קובץ של שורה או שתיים הוא המקרה שבו העדות דלה: ה-confidence אמור
      // לרדת, אבל הטקסט עצמו חייב לצאת נכון.
      final random = Random(1789);
      for (var iteration = 0; iteration < 150; iteration++) {
        final text = randomHebrewText(random, 15 + random.nextInt(60));
        for (final encoding in TextEncoding.values) {
          if (encoding.isLegacyHebrew && !canEncode(text, encoding)) continue;
          for (final bom in encoding.isLegacyHebrew ? [false] : [false, true]) {
            final bytes = encodeWith(text, encoding, bom: bom);
            expect(
              decodeTextBytesSmart(bytes),
              text,
              reason: 'טקסט קצר ב-${encoding.label} (BOM=$bom) לא שוחזר',
            );
          }
        }
      }
    });

    test('כפיית הקידוד שבו קודד הטקסט מחזירה אותו בדיוק', () {
      final random = Random(4321);
      for (var iteration = 0; iteration < 40; iteration++) {
        final text = randomHebrewText(random, 200 + random.nextInt(400));
        for (final encoding in TextEncoding.values) {
          if (encoding.isLegacyHebrew && !canEncode(text, encoding)) continue;
          final bytes = encodeWith(text, encoding);
          expect(
            decodeTextBytesWith(bytes, encoding),
            text,
            reason: 'כפיית ${encoding.label} אינה משחזרת את הטקסט',
          );
          expect(
            decodeTextBytesSmartDetailed(
              bytes,
              forcedEncoding: encoding,
            ).text,
            text,
          );
        }
      }
    });

    test('חיתוך הקובץ בכל נקודה אינו מפיל את הפענוח', () {
      // חיתוך אקראי מייצר בדיוק את מקרי הקצה שבשטח: רצף UTF-8 קטוע, חצי זוג
      // surrogate, אורך אי-זוגי, ו-BOM שנחתך באמצע.
      final random = Random(613);
      for (var iteration = 0; iteration < 60; iteration++) {
        final text = randomHebrewText(random, 120 + random.nextInt(200));
        for (final encoding in TextEncoding.values) {
          if (encoding.isLegacyHebrew && !canEncode(text, encoding)) continue;
          final full = encodeWith(text, encoding, bom: iteration.isEven);
          for (var trim = 0; trim < 6; trim++) {
            final cut = random.nextInt(full.length + 1);
            final bytes = Uint8List.sublistView(full, 0, cut);
            final result = decodeTextBytesSmartDetailed(bytes);
            expect(result.confidence, inInclusiveRange(0.0, 1.0));
            // כשהקידוד עדיין מזוהה נכון, הפלט חייב להיות **רישא** של הטקסט
            // המקורי: פענוח שחותך מהתחלה או ממציא תווים ייפול כאן.
            if (result.encoding == encoding) {
              expect(
                text.startsWith(result.text),
                isTrue,
                reason:
                    '${encoding.label} נחתך ב-$cut והפלט אינו רישא של המקור',
              );
            } else {
              expect(
                result.text.length,
                lessThanOrEqualTo(text.length),
                reason: '${encoding.label} נחתך ב-$cut',
              );
            }
          }
        }
      }
    });
  });
}
