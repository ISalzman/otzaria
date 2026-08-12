import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:path/path.dart' as path;

void main() {
  group('FileSystemData.scanHebrewBooksPdfFilesAtPath', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('otzaria-hb-pdfs-');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('מאתר PDF כשהנתיב מצביע ישירות לתיקיית הספרים', () async {
      final pdf = File(path.join(tempDir.path, '123.pdf'));
      await pdf.writeAsBytes(const [1]);

      final files = await FileSystemData.scanHebrewBooksPdfFilesAtPath(
        tempDir.path,
      );

      expect(files, {'123.pdf': pdf.path});
    });

    test('מאתר PDF תחת Books כשהנתיב מצביע לשורש HebrewBooks', () async {
      final booksDir = Directory(path.join(tempDir.path, 'Books'));
      await booksDir.create();
      final pdf = File(path.join(booksDir.path, '456.pdf'));
      await pdf.writeAsBytes(const [1]);

      final files = await FileSystemData.scanHebrewBooksPdfFilesAtPath(
        tempDir.path,
      );

      expect(files, {'456.pdf': pdf.path});
    });

    test(
      'מאתר PDF שהוא קישור סמלי',
      () async {
        final sourceDir = Directory(path.join(tempDir.path, 'source'));
        await sourceDir.create();
        final target = File(path.join(sourceDir.path, '789.pdf'));
        await target.writeAsBytes(const [1]);
        final link = Link(path.join(tempDir.path, '789.pdf'));
        await link.create(target.path);

        final files = await FileSystemData.scanHebrewBooksPdfFilesAtPath(
          tempDir.path,
        );

        expect(files, {'789.pdf': link.path});
      },
      skip: Platform.isWindows
          ? 'יצירת symlink דורשת הרשאה מיוחדת ב-Windows'
          : false,
    );
  });
}
