import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/disk_free_space.dart';
import 'package:path/path.dart' as p;

void main() {
  test('נתיב קיים מחזיר מקום פנוי חיובי ומזהה volume', () async {
    final info = await getDiskSpaceInfo(Directory.systemTemp.path);

    expect(info.freeBytes, greaterThan(0));
    expect(info.volumeId, isNotNull);
  });

  test('נתיב שאינו קיים מטפס לאב הקיים — לא unknown', () async {
    final missing = p.join(
      Directory.systemTemp.path,
      'otzaria_missing_dir',
      'deeper',
    );

    final info = await getDiskSpaceInfo(missing);

    expect(info.freeBytes, greaterThan(0));
    expect(
      info.volumeId,
      (await getDiskSpaceInfo(Directory.systemTemp.path)).volumeId,
    );
  });
}
