import 'dart:io';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/migration/models/category.dart' as migration_models;
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// בדיקות ל-write-session של [SqliteDataProvider]: seforim.db פתוח read-only,
/// וכתיבות עוברות דרך [SqliteDataProvider.withWritableSession] שמחזיר ל-RO.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String libraryPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('otzaria-write-session-');
    libraryPath = path.join(tempDir.path, 'library');
    final dataRootPath = path.join(tempDir.path, 'data_root');
    await Directory(libraryPath).create(recursive: true);

    await Settings.init(cacheProvider: _MemoryCacheProvider());
    AppPaths.debugOverrideDataRootPath(dataRootPath);

    await Settings.setValue<String>(
        SettingsRepository.keyLibraryPath, libraryPath);
    await Settings.setValue<String>(
        SettingsRepository.keyLibraryFolderName, '');
    await Settings.setValue<String>(SettingsRepository.keyDbEffectivePath, '');

    // בונים seforim.db עם קטגוריה אחת, ואז **סוגרים** — אסור להשאיר חיבור
    // מתחרה פתוח, אחרת ה-write-session ייתקל בנעילת קובץ.
    final dbPath = path.join(libraryPath, DatabaseConstants.databaseFileName);
    final db = MyDatabase.withPath(dbPath);
    final repo = SeforimRepository(db);
    await repo.ensureInitialized();
    await repo.insertCategory(const migration_models.Category(title: 'שורש'));
    db.close();

    await SqliteDataProvider.instance.dispose();
    await SqliteDataProvider.instance.initialize();
  });

  tearDown(() async {
    await SqliteDataProvider.instance.dispose();
    AppPaths.debugOverrideDataRootPath(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('החיבור הרגיל פתוח read-only — כתיבה ישירה נכשלת', () async {
    final repo = SqliteDataProvider.instance.repository;
    expect(repo, isNotNull);
    final db = await repo!.database.database;
    expect(
      () => db.execute("INSERT INTO category (title, level) VALUES ('x', 0)"),
      throwsA(isA<SqliteException>()),
    );
  });

  test('withWritableSession כותב, והכתיבה נראית אחרי החזרה ל-RO', () async {
    await SqliteDataProvider.instance.withWritableSession((rw) async {
      await rw.insertCategory(const migration_models.Category(title: 'חדש'));
    });

    // החיבור נפתח מחדש read-only.
    expect(SqliteDataProvider.instance.isInitialized, isTrue);

    final categories =
        await SqliteDataProvider.instance.repository!.getRootCategories();
    expect(
      categories.where((c) => c.title == 'חדש'),
      isNotEmpty,
      reason: 'הקטגוריה שנכתבה ב-write-session נראית בחיבור ה-RO',
    );

    // וה-RO עדיין חוסם כתיבה ישירה.
    final db = await SqliteDataProvider.instance.repository!.database.database;
    expect(
      () => db.execute("INSERT INTO category (title, level) VALUES ('y', 0)"),
      throwsA(isA<SqliteException>()),
    );
  });

  test('initialize() מקבילה ל-write-session אינה קורסת ואינה פותחת חיבור מתנגש',
      () async {
    final session = SqliteDataProvider.instance.withWritableSession((rw) async {
      // משהים כדי שה-initialize המקבילה תתפוס את ה-session כפעיל.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await rw.insertCategory(const migration_models.Category(title: 'במקביל'));
    });

    // קריאה מקבילה (כמו lazy-init של מסלול קריאה) — צריכה להמתין לסיום
    // השרשרת ולא לפתוח חיבור RO מתנגש מול ה-RW.
    await SqliteDataProvider.instance.initialize();
    await session;

    expect(SqliteDataProvider.instance.isInitialized, isTrue);
    final categories =
        await SqliteDataProvider.instance.repository!.getRootCategories();
    expect(categories.where((c) => c.title == 'במקביל'), isNotEmpty);
  });

  test('write-sessions סדרתיים — שתי כתיבות מצטברות', () async {
    await SqliteDataProvider.instance.withWritableSession((rw) async {
      await rw.insertCategory(const migration_models.Category(title: 'א'));
    });
    await SqliteDataProvider.instance.withWritableSession((rw) async {
      await rw.insertCategory(const migration_models.Category(title: 'ב'));
    });

    final titles =
        (await SqliteDataProvider.instance.repository!.getRootCategories())
            .map((c) => c.title)
            .toSet();
    expect(titles.containsAll({'א', 'ב'}), isTrue);
  });
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
  Future<void> setObject<T>(String key, T? value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String? value) async =>
      _values[key] = value;
}
