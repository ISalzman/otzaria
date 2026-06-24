import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/move_directory.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('otzaria_move_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  String src(String name) => p.join(tempDir.path, name);

  group('moveDirectory', () {
    test('מעביר קבצים ומוחק תיקיית המקור', () async {
      final source = src('from');
      final dest = src('to');
      await Directory(source).create();
      await File(p.join(source, 'file.txt')).writeAsString('שלום');

      final result = await moveDirectory(source, dest);

      expect(result, isNull);
      expect(await File(p.join(dest, 'file.txt')).readAsString(), 'שלום');
      expect(await Directory(source).exists(), isFalse);
    });

    test('מעביר תיקיות מקוננות', () async {
      final source = src('from');
      final dest = src('to');
      await Directory(p.join(source, 'sub')).create(recursive: true);
      await File(p.join(source, 'sub', 'nested.txt')).writeAsString('תוכן');

      final result = await moveDirectory(source, dest);

      expect(result, isNull);
      expect(await File(p.join(dest, 'sub', 'nested.txt')).exists(), isTrue);
    });

    test('מעביר מספר קבצים בתיקייה', () async {
      final source = src('from');
      await Directory(source).create();
      for (var i = 0; i < 5; i++) {
        await File(p.join(source, 'f$i.txt')).writeAsString('data $i');
      }

      await moveDirectory(source, src('to'));

      for (var i = 0; i < 5; i++) {
        expect(await File(p.join(src('to'), 'f$i.txt')).exists(), isTrue);
      }
    });

    test('מחזיר null כשמקור ויעד זהים (ללא פעולה)', () async {
      final dir = src('same');
      await Directory(dir).create();
      await File(p.join(dir, 'f.txt')).writeAsString('x');

      final result = await moveDirectory(dir, dir);

      expect(result, isNull);
      expect(await File(p.join(dir, 'f.txt')).exists(), isTrue);
    });

    test('יוצר את תיקיית היעד אם לא קיימת', () async {
      final source = src('from');
      final dest = src('a/b/c/dest');
      await Directory(source).create();
      await File(p.join(source, 'x.txt')).writeAsString('y');

      await moveDirectory(source, dest);

      expect(await File(p.join(dest, 'x.txt')).exists(), isTrue);
    });

    test('זורק Exception כשתיקיית המקור לא קיימת', () async {
      await expectLater(
        () => moveDirectory(src('nonexistent'), src('dest')),
        throwsA(isA<Exception>()),
      );
    });

    test('זורק Exception כשהיעד בתוך המקור', () async {
      final source = src('from');
      await Directory(source).create();

      await expectLater(
        () => moveDirectory(source, p.join(source, 'sub')),
        throwsA(isA<Exception>()),
      );
    });

    test('תיקיית יעד כבר קיימת — מאחד תכנים ולא זורק שגיאה', () async {
      final source = src('from');
      final dest = src('to');
      await Directory(source).create();
      await Directory(dest).create();
      await File(p.join(source, 'new.txt')).writeAsString('new');
      await File(p.join(dest, 'existing.txt')).writeAsString('old');

      final result = await moveDirectory(source, dest);

      expect(result, isNull);
      expect(await File(p.join(dest, 'new.txt')).exists(), isTrue);
      expect(await File(p.join(dest, 'existing.txt')).exists(), isTrue);
    });
  });
}
