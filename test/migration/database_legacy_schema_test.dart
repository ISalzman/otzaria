import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/dao/daos/database.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String dbPath;
  late MyDatabase database;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'otzaria-legacy-schema-test-',
    );
    dbPath = path.join(tempDir.path, 'legacy.db');

    final legacyDb = sqlite3.sqlite3.open(dbPath);
    legacyDb.execute('''
      CREATE TABLE category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parentId INTEGER,
        title TEXT NOT NULL,
        level INTEGER NOT NULL DEFAULT 0
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE line (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        lineIndex INTEGER NOT NULL,
        content TEXT NOT NULL,
        tocEntryId INTEGER
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE tocEntry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        parentId INTEGER,
        textId INTEGER NOT NULL,
        level INTEGER NOT NULL,
        lineId INTEGER,
        isLastChild INTEGER NOT NULL DEFAULT 0,
        hasChildren INTEGER NOT NULL DEFAULT 0
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE author (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      );
    ''');
    legacyDb.execute('''
      CREATE TABLE book (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER NOT NULL,
        sourceId INTEGER NOT NULL,
        title TEXT NOT NULL,
        heShortDesc TEXT,
        notesContent TEXT,
        orderIndex INTEGER NOT NULL DEFAULT 999,
        totalLines INTEGER NOT NULL DEFAULT 0,
        isBaseBook INTEGER NOT NULL DEFAULT 0,
        hasTargumConnection INTEGER NOT NULL DEFAULT 0,
        hasReferenceConnection INTEGER NOT NULL DEFAULT 0,
        hasSourceConnection INTEGER NOT NULL DEFAULT 0,
        hasCommentaryConnection INTEGER NOT NULL DEFAULT 0,
        hasOtherConnection INTEGER NOT NULL DEFAULT 0,
        hasAltStructures INTEGER NOT NULL DEFAULT 0,
        hasTeamim INTEGER NOT NULL DEFAULT 0,
        hasNekudot INTEGER NOT NULL DEFAULT 0,
        isContentExternal INTEGER DEFAULT 0,
        externalLibraryId TEXT DEFAULT NULL,
        isPersonal INTEGER DEFAULT 0,
        filePath TEXT DEFAULT NULL,
        fileType TEXT DEFAULT 'txt',
        fileSize INTEGER DEFAULT NULL,
        lastModified INTEGER DEFAULT NULL
      );
    ''');
    legacyDb.close();

    database = MyDatabase.withPath(dbPath);
  });

  tearDown(() async {
    database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('פותח מסד ישן ומרפא עמודות legacy לפני יצירת אינדקסים', () async {
    final db = await database.database;
    final categoryColumns = db.select('PRAGMA table_info(category)');
    final lineColumns = db.select('PRAGMA table_info(line)');
    final tocColumns = db.select('PRAGMA table_info(tocEntry)');
    final authorColumns = db.select('PRAGMA table_info(author)');
    final bookColumns = db.select('PRAGMA table_info(book)');

    expect(
      categoryColumns.any((row) => row['name'] == 'orderIndex'),
      isTrue,
    );
    expect(
      lineColumns.any((row) => row['name'] == 'heRef'),
      isTrue,
    );
    expect(
      tocColumns.any((row) => row['name'] == 'lineIndex'),
      isTrue,
    );
    expect(
      authorColumns.any((row) => row['name'] == 'generationId'),
      isTrue,
    );
    expect(
      bookColumns.any((row) => row['name'] == 'pages'),
      isTrue,
    );
    expect(
      bookColumns.any((row) => row['name'] == 'volume'),
      isTrue,
    );

    final categoryIndexes = db.select("PRAGMA index_list('category')");
    final lineIndexes = db.select("PRAGMA index_list('line')");
    final authorIndexes = db.select("PRAGMA index_list('author')");
    expect(
      categoryIndexes.any((row) => row['name'] == 'idx_category_order'),
      isTrue,
    );
    expect(
      lineIndexes.any((row) => row['name'] == 'idx_line_heref'),
      isTrue,
    );
    expect(
      authorIndexes.any((row) => row['name'] == 'idx_author_generation'),
      isTrue,
    );
  });
}
