import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:path/path.dart' as path;

/// רגרסיה: סכמת user_books.db (נוצרת ע"י [MyDatabase]) חייבת לכלול את
/// book_generation ו-user_link כדי לתמוך בדור ובקישורי-משתמש מיובאים.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('הרחבות סכמה ל-user_books.db', () {
    late Directory tempDir;
    late String dbPath;
    late MyDatabase database;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('otzaria_schema');
      dbPath = path.join(tempDir.path, 'user_books.db');
      database = MyDatabase.withPath(dbPath);
    });

    tearDown(() async {
      database.close();
      await tempDir.delete(recursive: true);
    });

    Future<Set<String>> tableNames() async {
      final db = await database.database;
      return db
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r['name'] as String)
          .toSet();
    }

    test('book_generation ו-user_link נוצרות ב-DB חדש', () async {
      final tables = await tableNames();
      expect(tables, contains('book_generation'));
      expect(tables, contains('user_link'));
    });

    test('user_link מכילה את העמודות הנדרשות לזיהוי יעד חוצה-DB', () async {
      final db = await database.database;
      final cols = db
          .select('PRAGMA table_info(user_link)')
          .map((r) => r['name'] as String)
          .toSet();
      expect(
        cols,
        containsAll([
          'sourceBookId',
          'sourceLineIndex',
          'targetTitle',
          'targetCategoryId',
          'targetIsUserBook',
          'targetRef',
          'targetLineIndex',
          'connectionType',
        ]),
      );
    });

    test('book_generation מצטרפת ל-generation ומחזירה את שם הדור', () async {
      final db = await database.database;
      db.execute('PRAGMA foreign_keys = OFF');
      db.execute("INSERT INTO generation (name) VALUES ('אחרונים')");
      final genId = db.lastInsertRowId;
      db.execute(
        "INSERT INTO source (name) VALUES ('external')",
      );
      final srcId = db.lastInsertRowId;
      db.execute(
        'INSERT INTO book (categoryId, sourceId, title) VALUES (1, ?, ?)',
        [srcId, 'ספר אישי'],
      );
      final bookId = db.lastInsertRowId;
      db.execute(
        'INSERT INTO book_generation (bookId, generationId) VALUES (?, ?)',
        [bookId, genId],
      );
      final rows = db.select(
        'SELECT g.name FROM book_generation bg '
        'JOIN generation g ON g.id = bg.generationId WHERE bg.bookId = ?',
        [bookId],
      );
      expect(rows.single['name'], 'אחרונים');
    });
  });
}
