import 'dart:convert';
import 'dart:io';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/data/data_providers/hive_data_provider.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/settings/services/backup_service.dart';
import 'package:otzaria/workspaces/workspace_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_service_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>(HiveCache.keyName);
    await Hive.openBox<dynamic>('workspaces');
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

    final result = await BackupService.createBackup(
      includeSettings: false,
      includeBookmarks: false,
      includeHistory: false,
      includeNotes: false,
      includeWorkspaces: false,
      includeShamorZachor: true,
      includeUserOverrides: false,
    );

    expect(result.skippedSections, isEmpty);

    final backupJson = jsonDecode(
      await File(result.path).readAsString(),
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

  test('restoreFromBackup משחזר currentWorkspace חדש לפי מזהה', () async {
    final backupDir = Directory(p.join(tempDir.path, 'workspace_backups'));
    await backupDir.create(recursive: true);
    final backupFile = File(p.join(backupDir.path, 'restore_workspace_id.json'));

    const firstWorkspaceId = 'workspace-a';
    const secondWorkspaceId = 'workspace-b';

    await backupFile.writeAsString(
      jsonEncode({
        'version': '1.0',
        'timestamp': '2026-05-04T00:00:00.000Z',
        'includes': {
          'settings': false,
          'bookmarks': false,
          'history': false,
          'notes': false,
          'workspaces': true,
          'shamorZachor': false,
          'userOverrides': false,
        },
        'workspaces': [
          {
            'id': firstWorkspaceId,
            'name': 'ראשון',
            'tabs': [],
            'currentTab': 0,
          },
          {
            'id': secondWorkspaceId,
            'name': 'שני',
            'tabs': [],
            'currentTab': 0,
          },
        ],
        'currentWorkspace': secondWorkspaceId,
      }),
    );

    await BackupService.restoreFromBackup(backupFile.path);

    final (workspaces, currentWorkspaceId) = WorkspaceRepository().loadWorkspaces();
    expect(workspaces, hasLength(2));
    expect(currentWorkspaceId, secondWorkspaceId);
  });

  test('restoreFromBackup תומך ב-currentWorkspace ישן כאינדקס', () async {
    final backupDir = Directory(p.join(tempDir.path, 'workspace_backups_legacy'));
    await backupDir.create(recursive: true);
    final backupFile = File(p.join(backupDir.path, 'restore_workspace_index.json'));

    const firstWorkspaceId = 'workspace-a';
    const secondWorkspaceId = 'workspace-b';

    await backupFile.writeAsString(
      jsonEncode({
        'version': '1.0',
        'timestamp': '2026-05-04T00:00:00.000Z',
        'includes': {
          'settings': false,
          'bookmarks': false,
          'history': false,
          'notes': false,
          'workspaces': true,
          'shamorZachor': false,
          'userOverrides': false,
        },
        'workspaces': [
          {
            'id': firstWorkspaceId,
            'name': 'ראשון',
            'tabs': [],
            'currentTab': 0,
          },
          {
            'id': secondWorkspaceId,
            'name': 'שני',
            'tabs': [],
            'currentTab': 0,
          },
        ],
        'currentWorkspace': 1,
      }),
    );

    await BackupService.restoreFromBackup(backupFile.path);

    final (workspaces, currentWorkspaceId) = WorkspaceRepository().loadWorkspaces();
    expect(workspaces.map((workspace) => workspace.id), [firstWorkspaceId, secondWorkspaceId]);
    expect(currentWorkspaceId, secondWorkspaceId);
  });

  // ─── shouldPerformAutoBackup ───────────────────────────────────────────────
  group('shouldPerformAutoBackup', () {
    setUp(() async {
      await Settings.setValue<String>('key-auto-backup-frequency', 'weekly');
      await Settings.setValue<String?>('key-last-auto-backup', null);
      await Settings.setValue<String?>('key-last-partial-auto-backup', null);
    });

    test('מחזיר false כש-frequency הוא none', () async {
      await Settings.setValue<String>('key-auto-backup-frequency', 'none');
      expect(await BackupService.shouldPerformAutoBackup(), isFalse);
    });

    test('מחזיר true כשאין גיבוי קודם (weekly)', () async {
      expect(await BackupService.shouldPerformAutoBackup(), isTrue);
    });

    test('מחזיר false כשגיבוי מלא לפני פחות מ-7 ימים (weekly)', () async {
      await Settings.setValue<String>(
        'key-last-auto-backup',
        DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      );
      expect(await BackupService.shouldPerformAutoBackup(), isFalse);
    });

    test('מחזיר true כשגיבוי מלא לפני יותר מ-7 ימים (weekly)', () async {
      await Settings.setValue<String>(
        'key-last-auto-backup',
        DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      );
      expect(await BackupService.shouldPerformAutoBackup(), isTrue);
    });

    test('מחזיר false כשגיבוי מלא לפני פחות מ-30 ימים (monthly)', () async {
      await Settings.setValue<String>('key-auto-backup-frequency', 'monthly');
      await Settings.setValue<String>(
        'key-last-auto-backup',
        DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
      );
      expect(await BackupService.shouldPerformAutoBackup(), isFalse);
    });

    test('מחזיר true כשגיבוי מלא לפני יותר מ-30 ימים (monthly)', () async {
      await Settings.setValue<String>('key-auto-backup-frequency', 'monthly');
      await Settings.setValue<String>(
        'key-last-auto-backup',
        DateTime.now().subtract(const Duration(days: 31)).toIso8601String(),
      );
      expect(await BackupService.shouldPerformAutoBackup(), isTrue);
    });

    test('מחזיר false אם partial cooldown פעיל (פחות משעה)', () async {
      await Settings.setValue<String>(
        'key-last-partial-auto-backup',
        DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      );
      expect(await BackupService.shouldPerformAutoBackup(), isFalse);
    });

    test('מחזיר true אם partial cooldown פג (יותר משעה)', () async {
      await Settings.setValue<String>(
        'key-last-partial-auto-backup',
        DateTime.now().subtract(const Duration(minutes: 90)).toIso8601String(),
      );
      expect(await BackupService.shouldPerformAutoBackup(), isTrue);
    });
  });
}
