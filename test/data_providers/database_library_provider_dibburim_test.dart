import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// טעינת דיבורי-המתחיל (`line_dh.dhDisplay`) — כולל מסדים ישנים, שבהם
/// הטבלה או העמודה עדיין לא קיימות, וחובה שיחזירו מפה ריקה בלי לזרוק.
void main() {
  late Directory tempDir;
  late String dbPath;
  late sqlite3.Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('otzaria_db_dibburim');
    dbPath = path.join(tempDir.path, 'db.sqlite');
    db = sqlite3.sqlite3.open(dbPath);
    db.execute('CREATE TABLE book (id INTEGER PRIMARY KEY, title TEXT)');
    db.execute("INSERT INTO book (id, title) VALUES (1, 'רש\"י על בראשית')");
  });

  tearDown(() async {
    db.close();
    await tempDir.delete(recursive: true);
  });

  Map<int, String> load([String title = 'רש"י על בראשית']) =>
      DatabaseLibraryProvider.loadDibburHamatchilForTesting(
        dbPath: dbPath,
        bookTitle: title,
      );

  test('מסד ישן בלי טבלת line_dh — מפה ריקה, בלי שגיאה', () {
    expect(load(), isEmpty);
  });

  test('טבלת line_dh בלי עמודת dhDisplay — מפה ריקה, בלי שגיאה', () {
    db.execute(
      'CREATE TABLE line_dh (bookId INTEGER NOT NULL, dhText TEXT NOT NULL, '
      'lineIndex INTEGER NOT NULL, PRIMARY KEY (bookId, dhText, lineIndex)) '
      'WITHOUT ROWID',
    );
    db.execute("INSERT INTO line_dh VALUES (1, 'בראשית', 3)");

    expect(load(), isEmpty);
  });

  test('מסד חדש — הצורה המודפסת לפי lineIndex, לספר המבוקש בלבד', () {
    db.execute(
      'CREATE TABLE line_dh (bookId INTEGER NOT NULL, dhText TEXT NOT NULL, '
      'lineIndex INTEGER NOT NULL, dhDisplay TEXT NOT NULL, '
      'PRIMARY KEY (bookId, dhText, lineIndex)) WITHOUT ROWID',
    );
    db.execute(
      "INSERT INTO line_dh VALUES (1, 'בראשית', 3, 'בְּרֵאשִׁית'), "
      "(1, 'ברא', 7, 'בָּרָא'), (2, 'אחר', 3, 'ספר אחר')",
    );

    expect(load(), {3: 'בְּרֵאשִׁית', 7: 'בָּרָא'});
    expect(load('ספר שאינו קיים'), isEmpty);
  });
}
