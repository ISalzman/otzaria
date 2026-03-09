import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseLibraryProvider', () {
    setUp(() async {
      await Settings.init(cacheProvider: _MemoryCacheProvider());
    });

    test('shouldIncludeBookByPath מסנן ספרי תלמוד בבלי כשהתיקייה חסרה', () {
      final filePath = path.join(
        '/library',
        DatabaseConstants.otzariaFolderName,
        DatabaseConstants.talmudBavliFolderName,
        'ברכות א.pdf',
      );

      expect(
        DatabaseLibraryProvider.shouldIncludeBookByPath(
          filePath,
          hasTalmudBavliDirectory: false,
          talmudBavliDirectoryPath: path.join(
            '/library',
            DatabaseConstants.otzariaFolderName,
            DatabaseConstants.talmudBavliFolderName,
          ),
        ),
        isFalse,
      );
    });

    test('shouldIncludeBookByPath משאיר קבצים אחרים גם כשהתיקייה חסרה', () {
      final otherFilePath = path.join(
        '/library',
        DatabaseConstants.otzariaFolderName,
        'משנה',
        'פאה.txt',
      );

      expect(
        DatabaseLibraryProvider.shouldIncludeBookByPath(
          otherFilePath,
          hasTalmudBavliDirectory: false,
          talmudBavliDirectoryPath: path.join(
            '/library',
            DatabaseConstants.otzariaFolderName,
            DatabaseConstants.talmudBavliFolderName,
          ),
        ),
        isTrue,
      );
    });

    test('isTalmudBavliFilePath מזהה נתיב מתוך התיקייה הייעודית', () {
      final filePath = path.join(
        '/library',
        'ספריה-מותאמת',
        DatabaseConstants.talmudBavliFolderName,
        'שבת ב.pdf',
      );

      expect(
        DatabaseConstants.isTalmudBavliFilePath(
          filePath,
          libraryPath: '/library',
          folderName: 'ספריה-מותאמת',
        ),
        isTrue,
      );
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
