import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show BackgroundIsolateBinaryMessenger, RootIsolateToken;
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/file_sync/repository/file_sync_repository.dart';
import 'package:otzaria/file_sync/library_diff_sync_worker.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite3lib;
import 'package:sqlite3/sqlite3.dart' show sqlite3;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp
        .createTemp('otzaria-diff-worker-test-');

    await Settings.init(cacheProvider: _MemoryCacheProvider());
    await Settings.setValue<String>(
      SettingsRepository.keyLibraryPath,
      tempDir.path,
    );
    await Settings.setValue<String>(
      SettingsRepository.keyLibraryFolderName,
      DatabaseConstants.otzariaFolderName,
    );

    final libDir = Directory(
      path.join(tempDir.path, DatabaseConstants.otzariaFolderName),
    );
    await libDir.create(recursive: true);

    dbPath = DatabaseConstants.getDatabasePath();
    _createMinimalDb(dbPath, version: 133);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('runDiffSyncLogic', () {
    test('שולח downloadProgress ומחיל SQL', () async {
      final updates = <LibraryDiffSyncUpdate>[];
      final fakeAsset = DiffReleaseAsset(
        fromVersion: 133,
        toVersion: 134,
        assetName: '133-134.DIFF.zst',
        downloadUrl: 'https://example.com/133-134.DIFF.zst',
        releaseTag: 'db-v134',
        releaseName: 'db-v134',
      );

      final fakeSql = '''
BEGIN TRANSACTION;
UPDATE db_meta SET value='134' WHERE key='content_version_int';
COMMIT;
''';

      await runDiffSyncLogic(
        dbPath: dbPath,
        assets: [fakeAsset],
        httpClient: MockClient((_) async =>
            http.Response.bytes(const [1, 2, 3], 200,
                headers: {'content-length': '3'})),
        decompress: (_) async => Uint8List.fromList(utf8.encode(fakeSql)),
        isCancelled: () => false,
        onProgress: updates.add,
      );

      expect(
        updates.whereType<LibraryDiffDownloadProgress>(),
        isNotEmpty,
        reason: 'צריך לפחות אחד downloadProgress',
      );
      expect(
        updates.whereType<LibraryDiffApplyProgress>(),
        isNotEmpty,
        reason: 'צריך לפחות אחד applyProgress',
      );
      expect(_readDbVersion(dbPath), 134);
    });

    test('מחיל כמה assets ברצף', () async {
      final updates = <LibraryDiffSyncUpdate>[];
      final assets = [
        DiffReleaseAsset(
          fromVersion: 133,
          toVersion: 134,
          assetName: '133-134.DIFF.zst',
          downloadUrl: 'https://example.com/133-134.DIFF.zst',
          releaseTag: 'v134',
          releaseName: 'v134',
        ),
        DiffReleaseAsset(
          fromVersion: 134,
          toVersion: 135,
          assetName: '134-135.DIFF.zst',
          downloadUrl: 'https://example.com/134-135.DIFF.zst',
          releaseTag: 'v135',
          releaseName: 'v135',
        ),
      ];

      var callCount = 0;
      Future<Uint8List?> fakeDecompress(Uint8List _) async {
        callCount++;
        final version = 133 + callCount;
        return Uint8List.fromList(utf8.encode(
          "UPDATE db_meta SET value='$version' WHERE key='content_version_int';",
        ));
      }

      final count = await runDiffSyncLogic(
        dbPath: dbPath,
        assets: assets,
        httpClient: MockClient((_) async =>
            http.Response.bytes(const [1], 200)),
        decompress: fakeDecompress,
        isCancelled: () => false,
        onProgress: updates.add,
      );

      expect(count, 2);
      expect(_readDbVersion(dbPath), 135);
    });

    test('ביטול בזמן הורדה זורק ומפסיק', () async {
      var cancelled = false;
      final updates = <LibraryDiffSyncUpdate>[];

      final asset = DiffReleaseAsset(
        fromVersion: 133,
        toVersion: 134,
        assetName: '133-134.DIFF.zst',
        downloadUrl: 'https://example.com/133-134.DIFF.zst',
        releaseTag: 'v134',
        releaseName: 'v134',
      );

      await expectLater(
        runDiffSyncLogic(
          dbPath: dbPath,
          assets: [asset],
          httpClient: MockClient((_) async {
            cancelled = true;
            return http.Response.bytes(const [1, 2, 3], 200);
          }),
          decompress: (_) async {
            fail('decompress לא אמור להיקרא אחרי ביטול');
          },
          isCancelled: () => cancelled,
          onProgress: updates.add,
        ),
        throwsA(isA<Object>()),
      );
    });

    test('שגיאת HTTP זורקת exception', () async {
      final asset = DiffReleaseAsset(
        fromVersion: 133,
        toVersion: 134,
        assetName: '133-134.DIFF.zst',
        downloadUrl: 'https://example.com/133-134.DIFF.zst',
        releaseTag: 'v134',
        releaseName: 'v134',
      );

      await expectLater(
        runDiffSyncLogic(
          dbPath: dbPath,
          assets: [asset],
          httpClient:
              MockClient((_) async => http.Response('Not Found', 404)),
          decompress: (_) async => null,
          isCancelled: () => false,
          onProgress: (_) {},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('LibraryDiffSyncWorkerService (inline)', () {
    test('stream מסתיים עם LibraryDiffSyncCompleted', () async {
      final asset = DiffReleaseAsset(
        fromVersion: 133,
        toVersion: 134,
        assetName: '133-134.DIFF.zst',
        downloadUrl: 'https://example.com/133-134.DIFF.zst',
        releaseTag: 'v134',
        releaseName: 'v134',
      );

      final fakeSql = "UPDATE db_meta SET value='134' WHERE key='content_version_int';";

      final service = LibraryDiffSyncWorkerService(
        httpClient: MockClient((_) async =>
            http.Response.bytes(const [1], 200)),
        decompressDiff: (_) async =>
            Uint8List.fromList(utf8.encode(fakeSql)),
      );

      final updates = await service
          .start(dbPath: dbPath, assets: [asset])
          .toList();

      expect(
        updates.last,
        isA<LibraryDiffSyncCompleted>(),
      );
      expect((updates.last as LibraryDiffSyncCompleted).appliedAssetCount, 1);
      expect(_readDbVersion(dbPath), 134);
    });

    test('ביטול מחזיר LibraryDiffSyncCancelled', () async {
      final asset = DiffReleaseAsset(
        fromVersion: 133,
        toVersion: 134,
        assetName: '133-134.DIFF.zst',
        downloadUrl: 'https://example.com/133-134.DIFF.zst',
        releaseTag: 'v134',
        releaseName: 'v134',
      );

      late LibraryDiffSyncWorkerService service;
      service = LibraryDiffSyncWorkerService(
        httpClient: MockClient((_) async {
          service.cancel();
          return http.Response.bytes(const [1], 200);
        }),
        decompressDiff: (_) async =>
            Uint8List.fromList(utf8.encode('SELECT 1;')),
      );

      final updates = await service
          .start(dbPath: dbPath, assets: [asset])
          .toList();

      expect(updates.last, isA<LibraryDiffSyncCancelled>());
    });

    test('שגיאה מחזירה LibraryDiffSyncFailed', () async {
      final asset = DiffReleaseAsset(
        fromVersion: 133,
        toVersion: 134,
        assetName: '133-134.DIFF.zst',
        downloadUrl: 'https://example.com/133-134.DIFF.zst',
        releaseTag: 'v134',
        releaseName: 'v134',
      );

      final service = LibraryDiffSyncWorkerService(
        httpClient: MockClient(
            (_) async => http.Response('Error', 500)),
        decompressDiff: (_) async => null,
      );

      final updates = await service
          .start(dbPath: dbPath, assets: [asset])
          .toList();

      expect(updates.last, isA<LibraryDiffSyncFailed>());
    });
  });

  group('LibraryDiffSyncWorkerService (real isolate)', () {
    final asset = DiffReleaseAsset(
      fromVersion: 133,
      toVersion: 134,
      assetName: 'fake.DIFF.zst',
      downloadUrl: 'https://example.com/fake.DIFF.zst',
      releaseTag: 'v134',
      releaseName: 'v134',
    );

    test('stream מסתיים עם LibraryDiffSyncCompleted דרך isolate אמיתי',
        () async {
      final service = LibraryDiffSyncWorkerService(
        isolateEntryPoint: _fakeIsolateProgressEntry,
      );

      final updates =
          await service.start(dbPath: dbPath, assets: [asset]).toList();

      expect(updates.last, isA<LibraryDiffSyncCompleted>());
      expect(
          (updates.last as LibraryDiffSyncCompleted).appliedAssetCount, 1);
      expect(_readDbVersion(dbPath), 200);
      expect(updates.whereType<LibraryDiffDownloadProgress>(), isNotEmpty);
    });

    test('ביטול לפני ready מחזיר LibraryDiffSyncCancelled', () async {
      final service = LibraryDiffSyncWorkerService(
        isolateEntryPoint: _fakeIsolateCancelEntry,
      );

      final stream = service.start(dbPath: dbPath, assets: [asset]);
      service.cancel();

      final updates = await stream.toList();
      expect(updates.last, isA<LibraryDiffSyncCancelled>());
    });
  });
}

// ── Top-level fake isolate entry points ──────────────────────────────────────

Future<void> _fakeIsolateProgressEntry(Map<String, dynamic> message) async {
  final mainSendPort = message['mainSendPort'] as SendPort;
  final token = message['token'] as RootIsolateToken;
  final dbPath = message['dbPath'] as String;

  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final commandPort = ReceivePort();
  mainSendPort.send({'type': 'ready', 'commandPort': commandPort.sendPort});
  commandPort.listen((_) {});

  final db = sqlite3lib.sqlite3.open(dbPath);
  db.execute(
      "UPDATE db_meta SET value='200' WHERE key='content_version_int'");
  db.close();

  mainSendPort.send({
    'type': 'downloadProgress',
    'assetName': 'fake.DIFF.zst',
    'downloadedBytes': 100,
    'totalBytes': 100,
  });
  mainSendPort.send({'type': 'completed', 'appliedAssetCount': 1});
  commandPort.close();
}

Future<void> _fakeIsolateCancelEntry(Map<String, dynamic> message) async {
  final mainSendPort = message['mainSendPort'] as SendPort;
  final token = message['token'] as RootIsolateToken;

  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final commandPort = ReceivePort();
  mainSendPort.send({'type': 'ready', 'commandPort': commandPort.sendPort});

  final completer = Completer<void>();
  commandPort.listen((msg) {
    if (msg is Map && msg['type'] == 'cancel' && !completer.isCompleted) {
      mainSendPort.send({'type': 'cancelled'});
      commandPort.close();
      completer.complete();
    }
  });

  await completer.future;
}

void _createMinimalDb(String dbPath, {required int version}) {
  final db = sqlite3.open(dbPath);
  db.execute('''
    CREATE TABLE IF NOT EXISTS db_meta (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
  db.execute(
    "INSERT OR REPLACE INTO db_meta (key, value) VALUES ('content_version_int', '$version')",
  );
  db.close();
}

int _readDbVersion(String dbPath) {
  final db = sqlite3.open(dbPath);
  try {
    final result = db
        .select("SELECT value FROM db_meta WHERE key='content_version_int'");
    return int.parse(result.first['value'] as String);
  } finally {
    db.close();
  }
}

class _MemoryCacheProvider extends CacheProvider {
  final Map<String, Object?> _values = {};

  @override
  Future<void> init() async {}

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Set getKeys() => _values.keys.toSet();

  @override
  bool? getBool(String key, {bool? defaultValue}) =>
      _values[key] as bool? ?? defaultValue;

  @override
  double? getDouble(String key, {double? defaultValue}) =>
      _values[key] as double? ?? defaultValue;

  @override
  int? getInt(String key, {int? defaultValue}) =>
      _values[key] as int? ?? defaultValue;

  @override
  String? getString(String key, {String? defaultValue}) =>
      _values[key] as String? ?? defaultValue;

  @override
  T? getValue<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    if (value is T) return value;
    return defaultValue;
  }

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> removeAll() async => _values.clear();

  @override
  Future<void> setBool(String key, bool? value) async => _values[key] = value;

  @override
  Future<void> setDouble(String key, double? value) async =>
      _values[key] = value;

  @override
  Future<void> setInt(String key, int? value) async => _values[key] = value;

  @override
  Future<void> setObject<T>(String key, T? value) async =>
      _values[key] = value;

  @override
  Future<void> setString(String key, String? value) async =>
      _values[key] = value;
}
