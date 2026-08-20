import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/save_file_with_extension.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('save_file_ext_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('ensureFileExtension', () {
    test(
      'קובץ בלי סיומת — משנה שם ומחזיר את הנתיב החדש (issue #817)',
      () async {
        final file = File('${tempDir.path}${Platform.pathSeparator}calendar');
        await file.writeAsBytes([1, 2, 3]);

        final result = await ensureFileExtension(file.path, 'pdf');

        expect(result, '${file.path}.pdf');
        expect(File(result).existsSync(), isTrue);
        expect(file.existsSync(), isFalse);
      },
    );

    test('סיומת קיימת — הנתיב מוחזר כמות שהוא', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}doc.pdf');
      await file.writeAsBytes([1]);

      expect(await ensureFileExtension(file.path, 'pdf'), file.path);
      expect(file.existsSync(), isTrue);
    });

    test('סיומת קיימת באותיות גדולות — לא משתנה', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}doc.PDF');
      await file.writeAsBytes([1]);

      expect(await ensureFileExtension(file.path, 'pdf'), file.path);
    });

    test('סיומת אחרת — מוסיף את המבוקשת בסוף', () async {
      final file = File('${tempDir.path}${Platform.pathSeparator}doc.txt');
      await file.writeAsBytes([1]);

      final result = await ensureFileExtension(file.path, 'pdf');
      expect(result, '${file.path}.pdf');
    });

    test('יעד קיים — נדרס בשם החדש', () async {
      final source = File('${tempDir.path}${Platform.pathSeparator}calendar');
      await source.writeAsBytes([7, 7]);
      final existing = File(
        '${tempDir.path}${Platform.pathSeparator}calendar.pdf',
      );
      await existing.writeAsBytes([1]);

      final result = await ensureFileExtension(source.path, 'pdf');

      expect(result, existing.path);
      expect(await File(result).readAsBytes(), [7, 7]);
    });

    test('הקובץ לא קיים — הנתיב מוחזר בלי שינוי', () async {
      final missing = '${tempDir.path}${Platform.pathSeparator}ghost';
      expect(await ensureFileExtension(missing, 'pdf'), missing);
    });
  });
}
