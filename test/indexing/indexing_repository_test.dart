import 'dart:io';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IndexingRepository.resolvePdfPathForIndexing', () {
    setUp(() async {
      await Settings.init(cacheProvider: _MemoryCacheProvider());
    });

    test('פותר נתיב יחסי לתוך תיקיית תלמוד בבלי הסמוכה ל-DB', () async {
      final tempDir = await Directory.systemTemp.createTemp('otzaria_indexing');
      final libraryRoot = Directory(
        p.join(tempDir.path, DatabaseConstants.otzariaFolderName),
      );
      final talmudDir = Directory(
        p.join(
          libraryRoot.path,
          DatabaseConstants.talmudBavliFolderName,
          'סדר זרעים',
        ),
      );
      final pdfFile = File(p.join(talmudDir.path, 'ברכות.pdf'));

      try {
        await talmudDir.create(recursive: true);
        await pdfFile.writeAsBytes(const [1, 2, 3]);

        await Settings.setValue<String>(
          'key-library-path',
          tempDir.path,
        );
        await Settings.setValue<String>(
          'key-library-folder-name',
          DatabaseConstants.otzariaFolderName,
        );

        final book = PdfBook(
          title: 'ברכות',
          path: 'סדר זרעים/ברכות',
          filePath: 'סדר זרעים/ברכות',
          categoryPath: 'תלמוד בבלי, סדר זרעים',
        );

        final resolved = IndexingRepository.resolvePdfPathForIndexing(book);

        expect(resolved, pdfFile.path);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('משאיר נתיב מוחלט קיים ללא שינוי', () async {
      final tempDir = await Directory.systemTemp.createTemp('otzaria_indexing_abs');
      final pdfFile = File(p.join(tempDir.path, 'שבת.pdf'));

      try {
        await pdfFile.writeAsBytes(const [1, 2, 3]);

        final book = PdfBook(
          title: 'שבת',
          path: pdfFile.path,
          filePath: pdfFile.path,
          categoryPath: 'תלמוד בבלי',
        );

        final resolved = IndexingRepository.resolvePdfPathForIndexing(book);

        expect(resolved, pdfFile.path);
      } finally {
        await tempDir.delete(recursive: true);
      }
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