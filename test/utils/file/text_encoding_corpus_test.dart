// קורפוס הזהב של זיהוי הקידודים: כל קובץ שהמחולל מייצר חייב להיות מזוהה,
// מפוענח ומדווח בדיוק כמתוכנן.
//
// הבדיקה מריצה את המחולל שב-`tool/generate_text_encoding_fixtures.dart`, ולכן
// אין קורפוס בינארי ב-git שיכול להסתאב מול הקוד.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/text_encoding.dart';

import '../../../tool/generate_text_encoding_fixtures.dart';

void main() {
  final directory = Directory.systemTemp.createTempSync('otzaria_encodings_');
  final fixtures = generateTextEncodingFixtures(directory);

  tearDownAll(() {
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException {
      // תיקיית temp שנשארה תפוסה אינה כשל של המוצר.
    }
  });

  test('המחולל ייצר קורפוס עשיר', () {
    expect(fixtures.length, greaterThanOrEqualTo(40));
    expect(
      File(
        '${directory.path}${Platform.pathSeparator}manifest.json',
      ).existsSync(),
      isTrue,
    );
  });

  for (final fixture in fixtures) {
    test('${fixture.file} — ${fixture.purpose}', () async {
      final file = File(
        '${directory.path}${Platform.pathSeparator}${fixture.file}',
      );
      final bytes = file.readAsBytesSync();
      final result = decodeTextBytesSmartDetailed(bytes);
      final detection = detectTextEncoding(bytes);
      final report = describeTextEncodingDetection(bytes);

      if (fixture.expectedEncoding != null) {
        expect(
          result.encoding,
          fixture.expectedEncoding,
          reason: 'קידוד שגוי.\n$report',
        );
      }
      if (fixture.expectedText != null) {
        expect(
          result.text,
          fixture.expectedText,
          reason: 'טקסט שגוי.\n$report',
        );
      }
      expect(
        result.confidence,
        inInclusiveRange(fixture.band.min, fixture.band.max),
        reason: 'confidence מחוץ לטווח ${fixture.band.name}.\n$report',
      );
      expect(result.hadBom, fixture.hadBom, reason: 'דיווח BOM שגוי.\n$report');
      if (fixture.forbidReplacementChar) {
        expect(
          result.text.contains('�'),
          isFalse,
          reason: 'הפלט מכיל תווי החלפה שקטים.\n$report',
        );
      }
      expect(result.encodingWasForced, isFalse);
      expect(result.detectionReason, isNotEmpty);

      // הזיהוי לבדו והפענוח המלא חייבים להסכים, ומסלול הקובץ זהה לזה שבזיכרון.
      expect(detection.encoding, result.encoding);
      expect(detection.confidence, result.confidence);
      expect(await readTextFileSmart(file), result.text);
    });
  }
}
