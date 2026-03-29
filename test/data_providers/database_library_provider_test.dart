import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/constants/database_constants.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

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

    test('getTalmudBavliDirectoryPath מחזיר נתיב ליד ה-DB גם בלי תיקיית אוצריא',
        () {
      expect(
        DatabaseConstants.getTalmudBavliDirectoryPath('/library-root', ''),
        path.join('/library-root', DatabaseConstants.talmudBavliFolderName),
      );
    });

    test('isTalmudBavliFilePath מזהה גם חילוץ ידני בשורש הספרייה', () {
      final filePath = path.join(
        '/library-root',
        DatabaseConstants.talmudBavliFolderName,
        'ברכות.pdf',
      );

      expect(
        DatabaseConstants.isTalmudBavliFilePath(
          filePath,
          libraryPath: '/library-root',
          folderName: DatabaseConstants.otzariaFolderName,
        ),
        isTrue,
      );
    });

    test('loadBookLinksRowsForTesting טוען קישורים דרך sqlite ב-isolate worker',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('otzaria_db_links');
      final dbPath = path.join(tempDir.path, 'db.sqlite');
      final db = sqlite3.sqlite3.open(dbPath);

      try {
        db.execute(
            'CREATE TABLE book (id INTEGER PRIMARY KEY, title TEXT, categoryId INTEGER, fileType TEXT)');
        db.execute(
            'CREATE TABLE line (id INTEGER PRIMARY KEY, lineIndex INTEGER, heRef TEXT)');
        db.execute(
            'CREATE TABLE connection_type (id INTEGER PRIMARY KEY, name TEXT)');
        db.execute(
            'CREATE TABLE link (sourceBookId INTEGER, sourceLineId INTEGER, targetLineId INTEGER, targetBookId INTEGER, connectionTypeId INTEGER)');

        db.execute(
            "INSERT INTO book (id, title, categoryId, fileType) VALUES (1, 'בראשית', 7, 'txt')");
        db.execute(
            "INSERT INTO book (id, title, categoryId, fileType) VALUES (2, 'רש''י על בראשית', 8, 'txt')");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (10, 0, 'א')");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (20, 3, 'ד')");
        db.execute(
            "INSERT INTO connection_type (id, name) VALUES (5, 'reference')");
        db.execute(
            'INSERT INTO link (sourceBookId, sourceLineId, targetLineId, targetBookId, connectionTypeId) VALUES (1, 10, 20, 2, 5)');

        final rows = DatabaseLibraryProvider.loadBookLinksRowsForTesting(
          dbPath: dbPath,
          title: 'בראשית',
          categoryId: 7,
          fileType: 'txt',
        );

        expect(rows, hasLength(1));
        expect(rows.first['sourceLineIndex'], 0);
        expect(rows.first['targetLineIndex'], 3);
        expect(rows.first['targetBookTitle'], 'רש\'י על בראשית');
        expect(rows.first['connectionTypeName'], 'reference');
      } finally {
        db.close();
        await tempDir.delete(recursive: true);
      }
    });

    test('loadBookLinksRowsInRangeForTesting מסנן לפי חלון שורות', () async {
      final tempDir = await Directory.systemTemp.createTemp('otzaria_db_range');
      final dbPath = path.join(tempDir.path, 'db.sqlite');
      final db = sqlite3.sqlite3.open(dbPath);

      try {
        db.execute(
            'CREATE TABLE book (id INTEGER PRIMARY KEY, title TEXT, categoryId INTEGER, fileType TEXT, orderIndex INTEGER)');
        db.execute(
            'CREATE TABLE line (id INTEGER PRIMARY KEY, lineIndex INTEGER, heRef TEXT)');
        db.execute(
            'CREATE TABLE connection_type (id INTEGER PRIMARY KEY, name TEXT)');
        db.execute(
            'CREATE TABLE link (sourceBookId INTEGER, sourceLineId INTEGER, targetLineId INTEGER, targetBookId INTEGER, connectionTypeId INTEGER)');

        db.execute(
            "INSERT INTO book (id, title, categoryId, fileType, orderIndex) VALUES (1, 'בראשית', 7, 'txt', 1)");
        db.execute(
            "INSERT INTO book (id, title, categoryId, fileType, orderIndex) VALUES (2, 'מפרש א', 8, 'txt', 1)");
        db.execute(
            "INSERT INTO book (id, title, categoryId, fileType, orderIndex) VALUES (3, 'מפרש ב', 8, 'txt', 2)");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (10, 4, 'ד')");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (11, 40, 'מ')");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (20, 0, 'א')");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (21, 1, 'ב')");
        db.execute(
            "INSERT INTO connection_type (id, name) VALUES (5, 'reference')");
        db.execute(
            'INSERT INTO link (sourceBookId, sourceLineId, targetLineId, targetBookId, connectionTypeId) VALUES (1, 10, 20, 2, 5)');
        db.execute(
            'INSERT INTO link (sourceBookId, sourceLineId, targetLineId, targetBookId, connectionTypeId) VALUES (1, 11, 21, 3, 5)');

        final rows = DatabaseLibraryProvider.loadBookLinksRowsInRangeForTesting(
          dbPath: dbPath,
          title: 'בראשית',
          categoryId: 7,
          fileType: 'txt',
          startLineIndex: 0,
          endLineIndex: 10,
        );

        expect(rows, hasLength(1));
        expect(rows.first['sourceLineIndex'], 4);
        expect(rows.first['targetBookTitle'], 'מפרש א');
      } finally {
        db.close();
        await tempDir.delete(recursive: true);
      }
    });

    test('loadBookLinksRowsInRangeForTesting מסנן גם לפי ספרי יעד', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('otzaria_db_target');
      final dbPath = path.join(tempDir.path, 'db.sqlite');
      final db = sqlite3.sqlite3.open(dbPath);

      try {
        db.execute(
            'CREATE TABLE book (id INTEGER PRIMARY KEY, title TEXT, categoryId INTEGER, fileType TEXT, orderIndex INTEGER)');
        db.execute(
            'CREATE TABLE line (id INTEGER PRIMARY KEY, lineIndex INTEGER, heRef TEXT)');
        db.execute(
            'CREATE TABLE connection_type (id INTEGER PRIMARY KEY, name TEXT)');
        db.execute(
            'CREATE TABLE link (sourceBookId INTEGER, sourceLineId INTEGER, targetLineId INTEGER, targetBookId INTEGER, connectionTypeId INTEGER)');

        db.execute(
            "INSERT INTO book (id, title, categoryId, fileType, orderIndex) VALUES (1, 'בראשית', 7, 'txt', 1)");
        db.execute(
            "INSERT INTO book (id, title, categoryId, fileType, orderIndex) VALUES (2, 'מפרש א', 8, 'txt', 1)");
        db.execute(
            "INSERT INTO book (id, title, categoryId, fileType, orderIndex) VALUES (3, 'מפרש ב', 8, 'txt', 2)");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (10, 4, 'ד')");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (11, 5, 'ה')");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (20, 0, 'א')");
        db.execute(
            "INSERT INTO line (id, lineIndex, heRef) VALUES (21, 1, 'ב')");
        db.execute(
            "INSERT INTO connection_type (id, name) VALUES (5, 'reference')");
        db.execute(
            'INSERT INTO link (sourceBookId, sourceLineId, targetLineId, targetBookId, connectionTypeId) VALUES (1, 10, 20, 2, 5)');
        db.execute(
            'INSERT INTO link (sourceBookId, sourceLineId, targetLineId, targetBookId, connectionTypeId) VALUES (1, 11, 21, 3, 5)');

        final rows = DatabaseLibraryProvider.loadBookLinksRowsInRangeForTesting(
          dbPath: dbPath,
          title: 'בראשית',
          categoryId: 7,
          fileType: 'txt',
          startLineIndex: 0,
          endLineIndex: 10,
          targetBookTitles: const ['מפרש ב'],
        );

        expect(rows, hasLength(1));
        expect(rows.first['sourceLineIndex'], 5);
        expect(rows.first['targetBookTitle'], 'מפרש ב');
      } finally {
        db.close();
        await tempDir.delete(recursive: true);
      }
    });

    test('loadAlternativeStructuresRowsForTesting טוען כותרות חלופיות מה-DB',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('otzaria_db_alt');
      final dbPath = path.join(tempDir.path, 'db.sqlite');
      final db = sqlite3.sqlite3.open(dbPath);

      try {
        db.execute('CREATE TABLE book (id INTEGER PRIMARY KEY, title TEXT)');
        db.execute(
            'CREATE TABLE alt_toc_structure (id INTEGER PRIMARY KEY, bookId INTEGER, key TEXT, title TEXT, heTitle TEXT)');

        db.execute("INSERT INTO book (id, title) VALUES (1, 'בראשית')");
        db.execute(
            "INSERT INTO alt_toc_structure (id, bookId, key, title, heTitle) VALUES (9, 1, 'chapters', 'Chapters', 'פרקים')");

        final rows =
            DatabaseLibraryProvider.loadAlternativeStructuresRowsForTesting(
          dbPath: dbPath,
          bookTitle: 'בראשית',
        );

        expect(rows, hasLength(1));
        expect(rows.first['id'], 9);
        expect(rows.first['bookId'], 1);
        expect(rows.first['key'], 'chapters');
        expect(rows.first['heTitle'], 'פרקים');
      } finally {
        db.close();
        await tempDir.delete(recursive: true);
      }
    });

    test('mergeLinksForTesting ממזג קישורים בלי כפילויות ושומר קישורים קודמים',
        () {
      final existing = [
        Link(
          heRef: 'א',
          index1: 75,
          path2: 'מפרש א',
          index2: 3,
          connectionType: 'reference',
        ),
        Link(
          heRef: 'ב',
          index1: 100,
          path2: 'מפרש ב',
          index2: 5,
          connectionType: 'reference',
        ),
      ];

      final incoming = [
        Link(
          heRef: 'ב',
          index1: 100,
          path2: 'מפרש ב',
          index2: 5,
          connectionType: 'reference',
        ),
        Link(
          heRef: 'ג',
          index1: 200,
          path2: 'מפרש ג',
          index2: 7,
          connectionType: 'reference',
        ),
      ];

      final merged = TextBookBloc.mergeLinksForTesting(existing, incoming);

      expect(merged, hasLength(3));
      expect(merged.map((link) => link.index1), [75, 100, 200]);
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
