import 'dart:convert';
import 'dart:io';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/data/data_providers/hive_data_provider.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/settings/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_service_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>(HiveCache.keyName);
    await Settings.init(cacheProvider: HiveCache());
    await Settings.setValue<String>(
      SettingsRepository.keyBackupPath,
      p.join(tempDir.path, 'backups'),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('createBackup מגבה מפתחות sz דינמיים מה-Box', () async {
    await box.put('sz:future_key', ['a', 'b']);
    await box.put('sz:progress_data', '{"tracked":true}');
    await box.put('other:key', 'ignored');

    final backupPath = await BackupService.createBackup(
      includeSettings: false,
      includeBookmarks: false,
      includeHistory: false,
      includeNotes: false,
      includeWorkspaces: false,
      includeShamorZachor: true,
      includeUserOverrides: false,
    );

    final backupJson = jsonDecode(
      await File(backupPath).readAsString(),
    ) as Map<String, dynamic>;
    final shamorZachor = backupJson['shamorZachor'] as Map<String, dynamic>;

    expect(shamorZachor['sz:future_key'], ['a', 'b']);
    expect(shamorZachor['sz:progress_data'], '{"tracked":true}');
    expect(shamorZachor.containsKey('other:key'), isFalse);
  });

  test('restoreFromBackup משחזר טיפוסים ישירות ל-Hive', () async {
    final backupDir = Directory(p.join(tempDir.path, 'manual_backups'));
    await backupDir.create(recursive: true);
    final backupFile = File(p.join(backupDir.path, 'restore.json'));

    await backupFile.writeAsString(
      jsonEncode({
        'version': '1.0',
        'timestamp': '2026-04-24T00:00:00.000Z',
        'includes': {
          'settings': false,
          'bookmarks': false,
          'history': false,
          'notes': false,
          'workspaces': false,
          'shamorZachor': true,
          'userOverrides': false,
        },
        'shamorZachor': {
          'sz:future_key': ['a', 'b'],
          'sz:migration_completed': true,
        },
      }),
    );

    await BackupService.restoreFromBackup(backupFile.path);

    expect(box.get('sz:future_key'), ['a', 'b']);
    expect(box.get('sz:migration_completed'), isTrue);
  });
}
