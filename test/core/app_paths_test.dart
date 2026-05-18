import 'dart:io';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: _MemoryCacheProvider());
    AppPaths.debugOverrideDataRootPath(null);
  });

  tearDown(() async {
    AppPaths.debugOverrideDataRootPath(null);
    Settings.clearCache();
  });

  group('AppPaths index paths', () {
    test('getIndexPath מעדיף legacy index תחת data root אם הוא קיים', () async {
      final dataRoot = await Directory.systemTemp.createTemp('otzaria_data_');
      final libraryRoot =
          await Directory.systemTemp.createTemp('otzaria_library_');
      final legacyIndex = Directory(p.join(dataRoot.path, 'index'));
      await legacyIndex.create(recursive: true);

      addTearDown(() async {
        if (await dataRoot.exists()) {
          await dataRoot.delete(recursive: true);
        }
        if (await libraryRoot.exists()) {
          await libraryRoot.delete(recursive: true);
        }
      });

      AppPaths.debugOverrideDataRootPath(dataRoot.path);
      await Settings.setValue(
        SettingsRepository.keyLibraryPath,
        p.join(libraryRoot.path, 'books'),
      );

      expect(await AppPaths.getIndexPath(), legacyIndex.path);
    });

    test('getTantivyLockPath מחזיר את הנתיב המועדף כשהוא כתיב', () async {
      final dataRoot = await Directory.systemTemp.createTemp('otzaria_data_');
      final libraryRoot =
          await Directory.systemTemp.createTemp('otzaria_library_');

      addTearDown(() async {
        if (await dataRoot.exists()) {
          await dataRoot.delete(recursive: true);
        }
        if (await libraryRoot.exists()) {
          await libraryRoot.delete(recursive: true);
        }
      });

      AppPaths.debugOverrideDataRootPath(dataRoot.path);
      await Settings.setValue(
        SettingsRepository.keyLibraryPath,
        p.join(libraryRoot.path, 'books'),
      );
      await Settings.setValue(
        SettingsRepository.keyIndexPath,
        p.join(libraryRoot.path, 'index'),
      );

      final lockPath = await AppPaths.getTantivyLockPath();
      expect(lockPath, p.join(libraryRoot.path, 'tantivy.lock'));
      expect(await Directory(lockPath).exists(), isTrue);
    });

    test('getTantivyLockPath נופל ל-data root כשהמיקום המועדף לא כתיב',
        () async {
      final dataRoot = await Directory.systemTemp.createTemp('otzaria_data_');
      final libraryRoot =
          await Directory.systemTemp.createTemp('otzaria_library_');

      addTearDown(() async {
        if (await dataRoot.exists()) {
          await dataRoot.delete(recursive: true);
        }
        if (await libraryRoot.exists()) {
          await libraryRoot.delete(recursive: true);
        }
      });

      // קובץ (לא תיקייה) שחוסם יצירת תת-תיקייה תחתיו.
      final blockingFile = File(p.join(libraryRoot.path, 'blocker'));
      await blockingFile.writeAsString('not a directory');

      AppPaths.debugOverrideDataRootPath(dataRoot.path);
      await Settings.setValue(
        SettingsRepository.keyLibraryPath,
        p.join(libraryRoot.path, 'books'),
      );
      // dirname = blockingFile (קובץ); יצירת tantivy.lock תחתיו תיכשל.
      await Settings.setValue(
        SettingsRepository.keyIndexPath,
        p.join(blockingFile.path, 'index'),
      );

      final lockPath = await AppPaths.getTantivyLockPath();
      expect(lockPath, p.join(dataRoot.path, 'tantivy_state'));
      expect(await Directory(lockPath).exists(), isTrue);
    });

    test(
        'getTantivyLockPath דבק ב-fallback גם כשהמיקום המועדף שב להיות כתיב',
        () async {
      final dataRoot = await Directory.systemTemp.createTemp('otzaria_data_');
      final libraryRoot =
          await Directory.systemTemp.createTemp('otzaria_library_');

      addTearDown(() async {
        if (await dataRoot.exists()) {
          await dataRoot.delete(recursive: true);
        }
        if (await libraryRoot.exists()) {
          await libraryRoot.delete(recursive: true);
        }
      });

      // מצב התחלתי: כבר קיים books_indexed.hive ב-fallback מסשן קודם.
      final fallbackDir = Directory(p.join(dataRoot.path, 'tantivy_state'));
      await fallbackDir.create(recursive: true);
      await File(p.join(fallbackDir.path, 'books_indexed.hive'))
          .writeAsString('stale state');

      AppPaths.debugOverrideDataRootPath(dataRoot.path);
      await Settings.setValue(
        SettingsRepository.keyLibraryPath,
        p.join(libraryRoot.path, 'books'),
      );
      // כאן preferredDir כן כתיב — אבל מצופה להישאר ב-fallback.
      await Settings.setValue(
        SettingsRepository.keyIndexPath,
        p.join(libraryRoot.path, 'index'),
      );

      final lockPath = await AppPaths.getTantivyLockPath();
      expect(lockPath, fallbackDir.path);
    });

    test('getTantivyLockPath ממוקטם וניתן לאיפוס דרך clearTantivyLockPathCache',
        () async {
      final dataRoot = await Directory.systemTemp.createTemp('otzaria_data_');
      final libraryRoot =
          await Directory.systemTemp.createTemp('otzaria_library_');

      addTearDown(() async {
        if (await dataRoot.exists()) {
          await dataRoot.delete(recursive: true);
        }
        if (await libraryRoot.exists()) {
          await libraryRoot.delete(recursive: true);
        }
      });

      AppPaths.debugOverrideDataRootPath(dataRoot.path);
      await Settings.setValue(
        SettingsRepository.keyLibraryPath,
        p.join(libraryRoot.path, 'books'),
      );
      await Settings.setValue(
        SettingsRepository.keyIndexPath,
        p.join(libraryRoot.path, 'index'),
      );

      final first = await AppPaths.getTantivyLockPath();

      // משנים את נתיב האינדקס בלי לקרוא ל-clear — הקאש מזהה את השינוי ב-key.
      final newLibraryRoot =
          await Directory.systemTemp.createTemp('otzaria_library2_');
      addTearDown(() async {
        if (await newLibraryRoot.exists()) {
          await newLibraryRoot.delete(recursive: true);
        }
      });
      await Settings.setValue(
        SettingsRepository.keyIndexPath,
        p.join(newLibraryRoot.path, 'index'),
      );

      final second = await AppPaths.getTantivyLockPath();
      expect(second, isNot(first));
      expect(second, p.join(newLibraryRoot.path, 'tantivy.lock'));

      // קריאה חוזרת ללא שינוי תחזיר את אותו הנתיב (cache hit).
      final third = await AppPaths.getTantivyLockPath();
      expect(third, second);

      // clearTantivyLockPathCache אינו משנה את התוצאה כשהקלט זהה.
      AppPaths.clearTantivyLockPathCache();
      final fourth = await AppPaths.getTantivyLockPath();
      expect(fourth, second);
    });

    test('getStaleDefaultIndexPaths מחזיר נתיבים מנורמלים וללא הנתיב הפעיל',
        () async {
      final dataRoot = await Directory.systemTemp.createTemp('otzaria_data_');
      final libraryRoot =
          await Directory.systemTemp.createTemp('otzaria_library_');

      addTearDown(() async {
        if (await dataRoot.exists()) {
          await dataRoot.delete(recursive: true);
        }
        if (await libraryRoot.exists()) {
          await libraryRoot.delete(recursive: true);
        }
      });

      AppPaths.debugOverrideDataRootPath(dataRoot.path);
      await Settings.setValue(
        SettingsRepository.keyLibraryPath,
        p.join(libraryRoot.path, 'books'),
      );
      await Settings.setValue(
        SettingsRepository.keyIndexPath,
        p.join(dataRoot.path, 'nested', '..', 'index'),
      );

      final stalePaths = await AppPaths.getStaleDefaultIndexPaths();

      expect(
        stalePaths,
        isNot(contains(p.normalize(p.join(dataRoot.path, 'index')))),
      );
      expect(
        stalePaths,
        contains(p.normalize(p.join(libraryRoot.path, 'index'))),
      );
      expect(stalePaths, everyElement(isNot(contains('..'))));
      expect(stalePaths, everyElement(predicate<String>((path) {
        return path == p.normalize(path);
      }, 'normalized path')));
      expect(stalePaths.toSet().length, stalePaths.length,
          reason: 'נתיבי stale צריכים להיות מנורמלים וללא כפילויות.');
    });
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
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> removeAll() async {
    _values.clear();
  }

  @override
  Future<void> setBool(String key, bool? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setObject<T>(String key, T? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String? value) async {
    _values[key] = value;
  }
}
