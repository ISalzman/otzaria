import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/archive_extractor.dart';

/// קובץ יחיד גדול הוא הצורה שיצרה את ה-ANR: החילוץ יוצא ל-event loop רק בין
/// קבצים, וארכיון התלמוד הוא 39 קובצי PDF של עד 38MB.
const _fileSizeMb = 16;

void main() {
  late Directory tempDir;
  late String tarPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('archive_extractor_test');
    final source = Directory('${tempDir.path}/source')
      ..createSync(recursive: true);
    final chunk = Uint8List(1024 * 1024);
    final raf = File(
      '${source.path}/big.bin',
    ).openSync(mode: FileMode.writeOnly);
    for (var i = 0; i < _fileSizeMb; i++) {
      raf.writeFromSync(chunk);
    }
    raf.closeSync();
    tarPath = '${tempDir.path}/archive.tar';
    await TarFileEncoder().tarDirectory(source, filename: tarPath);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('מחלץ את תוכן הארכיון אל תיקיית היעד', () async {
    final target = '${tempDir.path}/out';

    await extractArchiveFileToDisk(tarPath, target);

    final extracted = File('$target/source/big.bin');
    expect(extracted.existsSync(), isTrue);
    expect(extracted.lengthSync(), _fileSizeMb * 1024 * 1024);
  });

  test('אינו חוסם את לולאת ההודעות של ה-isolate הקורא', () async {
    final target = '${tempDir.path}/out';

    // בחילוץ על ה-isolate הקורא הספירה חסומה במספר נקודות ה-await שבחילוץ
    // (בודדות לקובץ אחד) ואינה גדלה עם הזמן — לכן הסף אינו תלוי במכונה.
    var eventLoopTurns = 0;
    var keepSpinning = true;
    Future<void> spin() async {
      while (keepSpinning) {
        await Future<void>.delayed(Duration.zero);
        eventLoopTurns++;
      }
    }

    final spinner = spin();
    await extractArchiveFileToDisk(tarPath, target);
    keepSpinning = false;
    await spinner;

    expect(File('$target/source/big.bin').existsSync(), isTrue);
    expect(eventLoopTurns, greaterThan(20));
  });

  test('שגיאת חילוץ חוצה את גבול ה-isolate עם הטיפוס המקורי', () async {
    await expectLater(
      extractArchiveFileToDisk(
        '${tempDir.path}/missing.tar',
        '${tempDir.path}/out',
      ),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      extractArchiveFileToDisk(
        '${tempDir.path}/archive',
        '${tempDir.path}/out',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('כל החילוצים ב-lib עוברים דרך extractArchiveFileToDisk', () {
    const helperPath = 'lib/utils/file/archive_extractor.dart';
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceAll(r'\', '/');
      if (relative.endsWith(helperPath)) continue;
      if (entity.readAsStringSync().contains('extractFileToDisk(')) {
        offenders.add(relative);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'קריאה ישירה ל-extractFileToDisk חוסמת את ה-isolate הקורא — '
          'יש לקרוא ל-extractArchiveFileToDisk',
    );
  });
}
