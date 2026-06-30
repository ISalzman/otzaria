import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/database/daos/database.dart';
import 'package:otzaria/user_content_import/models/user_import_models.dart';
import 'package:otzaria/user_content_import/repository/user_content_repository.dart';
import 'package:otzaria/user_content_import/services/user_content_importer.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserContentImporter.importFolder', () {
    late Directory tempDir;
    late Directory folder;
    late MyDatabase db;
    late UserContentRepository repo;
    late int bookId;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('otzaria_import');
      folder = Directory(p.join(tempDir.path, 'ספרים אישיים'))
        ..createSync(recursive: true);
      db = MyDatabase.withPath(p.join(tempDir.path, 'user_books.db'));
      final raw = await db.database;
      raw.execute('PRAGMA foreign_keys = OFF');
      raw.execute("INSERT INTO source (name) VALUES ('external')");
      raw.execute(
        'INSERT INTO book (categoryId, sourceId, title) VALUES (1, 1, ?)',
        ['ביאורי יוסף'],
      );
      bookId = raw.lastInsertRowId;
      repo = UserContentRepository(db);
    });

    tearDown(() async {
      db.close();
      await tempDir.delete(recursive: true);
    });

    void writeCsv(String name, String content) {
      File(p.join(folder.path, name)).writeAsStringSync(content);
    }

    test('קולט דור וקישורים וכותב ל-DB', () async {
      writeCsv('דורות.csv', 'ספר,דור,מחבר\nביאורי יוסף,מחברי זמננו,יוסף כהן\n');
      writeCsv(
        'ביאורי יוסף.links.csv',
        'מקור,ספר_יעד,מיקום_יעד,סוג,יעד_אישי\n'
            '12,ברכות,5,פירוש,לא\n'
            '47,שולחן ערוך אורח חיים,רטו א,הפניה,לא\n',
      );

      final result = await UserContentImporter.importFolder(folder.path, db);
      expect(result.errors, isEmpty);
      expect(result.generationsApplied, 1);
      expect(result.linksApplied, 2);

      final info = await repo.generationIdByName('מחברי זמננו');
      expect(info, isNotNull);
      final raw = await db.database;
      final gen = raw.select(
        'SELECT g.name FROM book_generation bg '
        'JOIN generation g ON g.id = bg.generationId WHERE bg.bookId = ?',
        [bookId],
      );
      expect(gen.single['name'], 'מחברי זמננו');

      final links = await repo.forwardUserLinks(bookId);
      expect(links.length, 2);
      // ממוין לפי sourceLineIndex; 1-based בקובץ → 0-based ב-DB
      expect(links[0].sourceLineIndex, 11);
      expect(links[0].targetTitle, 'ברכות');
      expect(links[0].connectionType, 'COMMENTARY');
      expect(links[0].targetLineIndex, 4); // "5" → אינדקס 4
      // ref לא-מספרי נשמר כ-ref גולמי, בלי אינדקס
      expect(links[1].targetRef, 'רטו א');
      expect(links[1].targetLineIndex, isNull);
      expect(links[1].connectionType, 'REFERENCE');
    });

    test('קולט קישורים מקובץ JSON', () async {
      writeCsv(
        'ביאורי יוסף.links.json',
        '[{"מקור": 12, "ספר_יעד": "ברכות", "מיקום_יעד": 5, "סוג": "פירוש"},'
            '{"מקור": 47, "ספר_יעד": "ברכות", "מיקום_יעד": 8, "סוג": "הפניה"}]',
      );
      final result = await UserContentImporter.importFolder(folder.path, db);
      expect(result.errors, isEmpty);
      expect(result.linksApplied, 2);
      final links = await repo.forwardUserLinks(bookId);
      expect(links.length, 2);
      expect(links[0].targetLineIndex, 4);
      expect(links[0].connectionType, 'COMMENTARY');
      expect(links[1].connectionType, 'REFERENCE');
    });

    test('ייבוא חוזר מחליף (idempotent) — לא מכפיל', () async {
      writeCsv('ביאורי יוסף.links.csv',
          'מקור,ספר_יעד,מיקום_יעד,סוג\n12,ברכות,5,פירוש\n');
      await UserContentImporter.importFolder(folder.path, db);
      await UserContentImporter.importFolder(folder.path, db);
      final links = await repo.forwardUserLinks(bookId);
      expect(links.length, 1);
    });

    test('קישור הפוך נמצא לפי כותרת היעד', () async {
      writeCsv('ביאורי יוסף.links.csv',
          'מקור,ספר_יעד,מיקום_יעד,סוג\n12,ברכות,5,פירוש\n');
      await UserContentImporter.importFolder(folder.path, db);
      final inverse =
          await repo.inverseUserLinks('ברכות', targetIsUserBook: false);
      expect(inverse.length, 1);
      expect(inverse.single.sourceBookId, bookId);
      expect(inverse.single.connectionType, 'COMMENTARY');
    });

    test('ספר לא קיים בדורות → שגיאה, אין כתיבה', () async {
      writeCsv('דורות.csv', 'ספר,דור\nספר שלא קיים,ראשונים\n');
      final result = await UserContentImporter.importFolder(folder.path, db);
      expect(result.generationsApplied, 0);
      expect(result.errors, isNotEmpty);
    });

    test('תיקייה בלי CSV → תוצאה ריקה (לא נוגע בנתונים קיימים)', () async {
      // קישור קיים מראש — סריקה בלי CSV לא אמורה למחוק אותו.
      await repo.replaceUserLinksForBook(bookId, [
        UserLinkRecord(
          sourceBookId: bookId,
          sourceLineIndex: 0,
          targetTitle: 'ברכות',
          connectionType: 'COMMENTARY',
        ),
      ]);
      final result = await UserContentImporter.importFolder(folder.path, db);
      expect(result.hasAny, isFalse);
      expect((await repo.forwardUserLinks(bookId)).length, 1);
    });

    test('מחיקת קובץ קישורים מסירה את הקישורים הישנים (idempotent)', () async {
      final f = File(p.join(folder.path, 'ביאורי יוסף.links.csv'));
      f.writeAsStringSync('מקור,ספר_יעד,מיקום_יעד,סוג\n12,ברכות,5,פירוש\n');
      await UserContentImporter.importFolder(folder.path, db);
      expect((await repo.forwardUserLinks(bookId)).length, 1);

      // הקובץ נמחק אך נשאר CSV אחר (מקור-אמת קיים) → הקישורים מוסרים.
      f.deleteSync();
      File(p.join(folder.path, 'דורות.csv'))
          .writeAsStringSync('ספר,דור\nביאורי יוסף,אחרונים\n');
      await UserContentImporter.importFolder(folder.path, db);
      expect(await repo.forwardUserLinks(bookId), isEmpty);
    });

    test('הסרת שורה מ-דורות.csv מסירה את הדור (idempotent)', () async {
      final g = File(p.join(folder.path, 'דורות.csv'));
      g.writeAsStringSync('ספר,דור\nביאורי יוסף,אחרונים\n');
      await UserContentImporter.importFolder(folder.path, db);
      final raw = await db.database;
      expect(
        raw.select('SELECT * FROM book_generation WHERE bookId=?', [bookId]),
        isNotEmpty,
      );

      // נשארת רק שורת הכותרת — הדור מוסר.
      g.writeAsStringSync('ספר,דור\n');
      await UserContentImporter.importFolder(folder.path, db);
      expect(
        raw.select('SELECT * FROM book_generation WHERE bookId=?', [bookId]),
        isEmpty,
      );
    });

    test('קובץ CSV/JSON לא-מוכר אינו גורר ניקוי', () async {
      await repo.replaceUserLinksForBook(bookId, [
        UserLinkRecord(
          sourceBookId: bookId,
          sourceLineIndex: 0,
          targetTitle: 'ברכות',
          connectionType: 'COMMENTARY',
        ),
      ]);
      writeCsv('notes.csv', 'a,b\n1,2\n');
      File(p.join(folder.path, 'data.json')).writeAsStringSync('{"x":1}');
      final result = await UserContentImporter.importFolder(folder.path, db);
      expect(result.hasAny, isFalse);
      expect((await repo.forwardUserLinks(bookId)).length, 1);
    });

    test('קובץ קישורים עם שורה פגומה אינו מחליף קישורים קיימים (אטומי)',
        () async {
      await repo.replaceUserLinksForBook(bookId, [
        UserLinkRecord(
          sourceBookId: bookId,
          sourceLineIndex: 99,
          targetTitle: 'קיים',
          connectionType: 'COMMENTARY',
        ),
      ]);
      writeCsv(
        'ביאורי יוסף.links.csv',
        'מקור,ספר_יעד,מיקום_יעד,סוג\n12,ברכות,5,פירוש\nאבג,ברכות,5,פירוש\n',
      );
      final result = await UserContentImporter.importFolder(folder.path, db);
      expect(result.errors, isNotEmpty);
      final links = await repo.forwardUserLinks(bookId);
      expect(links.length, 1);
      expect(links.single.sourceLineIndex, 99); // הישן נשמר, לא הוחלף חלקית
    });

    test('שגיאת פענוח לא מוחקת נתונים קיימים', () async {
      await repo.replaceUserLinksForBook(bookId, [
        UserLinkRecord(
          sourceBookId: bookId,
          sourceLineIndex: 0,
          targetTitle: 'ברכות',
          connectionType: 'COMMENTARY',
        ),
      ]);
      // CSV עם שגיאה (ספר שאינו קיים) — אסור שימחק את הקישור הקיים.
      writeCsv('דורות.csv', 'ספר,דור\nספר שלא קיים,ראשונים\n');
      final result = await UserContentImporter.importFolder(folder.path, db);
      expect(result.errors, isNotEmpty);
      expect((await repo.forwardUserLinks(bookId)).length, 1);
    });

    test('inverseUserLinks מסנן לפי targetCategoryId', () async {
      await repo.replaceUserLinksForBook(bookId, [
        UserLinkRecord(
          sourceBookId: bookId,
          sourceLineIndex: 0,
          targetTitle: 'משותף',
          targetCategoryId: 10,
          targetLineIndex: 0,
          connectionType: 'COMMENTARY',
        ),
        UserLinkRecord(
          sourceBookId: bookId,
          sourceLineIndex: 1,
          targetTitle: 'משותף',
          targetCategoryId: 20,
          targetLineIndex: 1,
          connectionType: 'COMMENTARY',
        ),
        UserLinkRecord(
          sourceBookId: bookId,
          sourceLineIndex: 2,
          targetTitle: 'משותף',
          targetLineIndex: 2,
          connectionType: 'COMMENTARY',
        ),
      ]);
      // קטגוריה 10 + השורה ללא קטגוריה; לא קטגוריה 20.
      final cat10 = await repo.inverseUserLinks('משותף',
          targetIsUserBook: false, targetCategoryId: 10);
      expect(cat10.length, 2);
      final all = await repo.inverseUserLinks('משותף', targetIsUserBook: false);
      expect(all.length, 3);
    });
  });
}
