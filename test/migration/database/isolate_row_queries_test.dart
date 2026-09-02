import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/migration/models/toc_entry.dart';
import 'package:path/path.dart' as path;

/// שני ה-accessors האלה הם החוזה של ה-isolate המשותף: הם מחזירים שורות כמפות
/// שחייבות להתאים למסלול המודלים הרגיל ולהיות ברות-סריאליזציה. חציית גבול
/// isolate אמיתית נבדקת ב-test/find_ref/find_ref_db_isolate_shared_queries_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MyDatabase database;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('otzaria_isolate_rows');
    database = MyDatabase.withPath(path.join(tempDir.path, 'seforim.db'));
    final db = await database.database;
    db.execute("INSERT INTO category (id, title, level) VALUES (7, 'תנך', 0)");
    db.execute("INSERT INTO source (id, name) VALUES (1, 'אוצריא')");
    db.execute(
      "INSERT INTO book (id, categoryId, sourceId, title, orderIndex, "
      "filePath, fileType, heShortDesc) VALUES "
      "(2, 7, 1, 'שמות', 5, '/b/shmot.txt', 'txt', 'תיאור ארוך')",
    );
    db.execute(
      "INSERT INTO book (id, categoryId, sourceId, title, orderIndex, "
      "filePath, fileType) VALUES (1, 7, 1, 'בראשית', 3, '/b/br.pdf', 'pdf')",
    );
    db.execute(
      "INSERT INTO tocText (id, text) VALUES (1, 'פרק א'), (2, 'פרק ב')",
    );
    db.execute(
      "INSERT INTO line (id, bookId, lineIndex, content) VALUES "
      "(100, 1, 0, 'בראשית'), (101, 1, 4, 'ויאמר')",
    );
    db.execute(
      'INSERT INTO tocEntry (id, bookId, parentId, textId, level, lineId) '
      'VALUES (10, 1, NULL, 1, 0, 100), (11, 1, 10, 2, 1, 101)',
    );
  });

  tearDown(() async {
    database.close();
    await tempDir.delete(recursive: true);
  });

  test('selectAllLocalBooksSlim מחזיר בדיוק את שדות הקאש, באותו סדר', () async {
    final slim = await database.bookDao.selectAllLocalBooksSlim();
    final full = await database.bookDao.getAllLocalBooks();

    expect(slim.map((r) => r['id']), full.map((b) => b.id));
    expect(slim.first.keys.toSet(), {
      'id',
      'title',
      'filePath',
      'fileType',
      'categoryId',
      'orderIndex',
    });
    expect(slim.first['title'], 'בראשית'); // ORDER BY orderIndex
    expect(slim.first['fileType'], 'pdf');
    expect(slim.last['orderIndex'], 5);
  });

  test(
    'selectByBookId זהה למיפוי השורות הגולמיות דרך TocEntry.fromMap',
    () async {
      final rows = await database.tocDao.selectRowsByBookId(1);
      final mapped = rows.map(TocEntry.fromMap).toList();
      final direct = await database.tocDao.selectByBookId(1);

      expect(mapped, hasLength(2));
      expect(mapped.map((e) => e.id), direct.map((e) => e.id));
      expect(mapped.map((e) => e.text), direct.map((e) => e.text));
      expect(mapped.map((e) => e.lineIndex), direct.map((e) => e.lineIndex));
      expect(mapped.map((e) => e.parentId), direct.map((e) => e.parentId));
    },
  );

  test('שתי קבוצות השורות עוברות סריאליזציה של פורט ומגיעות שלמות', () async {
    final books = await database.bookDao.selectAllLocalBooksSlim();
    final toc = await database.tocDao.selectRowsByBookId(1);

    final port = ReceivePort();
    port.sendPort.send([books, toc]);
    final received = await port.first as List;
    port.close();

    final rtBooks = (received[0] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    final rtToc = (received[1] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();

    expect(rtBooks.map((r) => r['title']), ['בראשית', 'שמות']);
    expect(rtToc.map(TocEntry.fromMap).map((e) => e.text), ['פרק א', 'פרק ב']);
  });
}
