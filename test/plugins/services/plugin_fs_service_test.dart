import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_fs_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late PluginFsService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('plugin_fs_test_');
    service = PluginFsService();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// יוצרת קובץ ZIP ב-[zipPath] המכיל את [entries] (שם יחסי → תוכן).
  String buildZip(String zipPath, Map<String, String> entries) {
    final srcDir = Directory(p.join(tempDir.path, 'src_${entries.hashCode}'))
      ..createSync(recursive: true);
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    try {
      entries.forEach((name, content) {
        final f = File(p.join(srcDir.path, name))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(content);
        encoder.addFileSync(f, name);
      });
    } finally {
      encoder.closeSync();
    }
    return zipPath;
  }

  group('PluginFsService.extractZip', () {
    test('מחלץ קבצים אל תיקיית היעד ויוצר אותה אם אינה קיימת', () async {
      final zipPath = buildZip(p.join(tempDir.path, 'a.zip'), {
        'hello.txt': 'שלום עולם',
        'sub/inner.txt': 'פנימי',
      });
      final destFolder = p.join(tempDir.path, 'out', 'nested');

      await service.extractZip(zipPath, destFolder);

      final hello = File(p.join(destFolder, 'hello.txt'));
      final inner = File(p.join(destFolder, 'sub', 'inner.txt'));
      expect(await hello.exists(), isTrue);
      expect(await hello.readAsString(), 'שלום עולם');
      expect(await inner.exists(), isTrue);
      expect(await inner.readAsString(), 'פנימי');
    });

    test('זורק כשקובץ ה-ZIP אינו קיים', () async {
      await expectLater(
        service.extractZip(
            p.join(tempDir.path, 'missing.zip'), p.join(tempDir.path, 'out')),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('PluginFsService.deleteFile', () {
    test('מוחק קובץ קיים', () async {
      final file = File(p.join(tempDir.path, 'x.txt'))
        ..writeAsStringSync('data');
      expect(await file.exists(), isTrue);

      await service.deleteFile(file.path);

      expect(await file.exists(), isFalse);
    });

    test('idempotent — אינו זורק כשהקובץ אינו קיים', () async {
      await service.deleteFile(p.join(tempDir.path, 'nope.txt'));
      // ללא חריגה — הצלחה שקטה.
    });

    test('זורק כשהנתיב הוא תיקייה', () async {
      final dir = Directory(p.join(tempDir.path, 'adir'))
        ..createSync(recursive: true);
      await expectLater(
        service.deleteFile(dir.path),
        throwsA(isA<Exception>()),
      );
    });
  });
}
