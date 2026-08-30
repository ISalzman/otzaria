import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/database_library_provider.dart';
import 'package:otzaria/data/data_providers/link_visibility_sql.dart';
import 'package:otzaria/models/link_types.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// נראות פר-צד (סכמה 3), נבדקת דרך **שאילתות הייצור עצמן** — הוקי
/// ה-`…ForTesting` של [DatabaseLibraryProvider] — ולא דרך SQL שהטסט מנסח
/// לעצמו. אחרת החלפת `displayedSide` באחד מאתרי ההזרקה הייתה עוברת בשקט.
void main() {
  late Directory tmp;

  /// מסד בצורת הסכמה האמיתית: ‏A (בסיס, 2 שורות) ↔ B (מצטג).
  /// link 1: A→B ‏OTHER, צד 0 יידוכא — ציטוט "פרק שלם", כולל שורת coverage
  /// link 2: A→B ‏OTHER, גלוי
  /// link 3: A→B ‏COMMENTARY — תלוי-טקסט, עולה הפוך תמיד
  String buildDb({required bool withTable, bool populate = true}) {
    final path = '${tmp.path}/links_${withTable}_$populate.db';
    final db = sqlite3.sqlite3.open(path);
    db.execute('''
      CREATE TABLE category (id INTEGER PRIMARY KEY, parentId INTEGER, title TEXT,
        level INTEGER, orderIndex INTEGER, heShortDesc TEXT, heDesc TEXT);
      CREATE TABLE source (id INTEGER PRIMARY KEY, name TEXT);
      CREATE TABLE book (id INTEGER PRIMARY KEY, categoryId INTEGER, sourceId INTEGER,
        title TEXT, heRef TEXT, heShortDesc TEXT, notesContent TEXT, orderIndex INTEGER,
        isBaseBook INTEGER, totalLines INTEGER, hasAltStructures INTEGER,
        hasTeamim INTEGER, hasNekudot INTEGER, dependenceType TEXT, filePath TEXT,
        fileType TEXT);
      CREATE TABLE line (id INTEGER PRIMARY KEY, bookId INTEGER, lineIndex INTEGER,
        content TEXT, heRef TEXT, tocEntryId INTEGER, charCount INTEGER);
      CREATE TABLE connection_type (id INTEGER PRIMARY KEY, name TEXT);
      CREATE TABLE link (id INTEGER PRIMARY KEY, sourceBookId INTEGER, targetBookId INTEGER,
        sourceLineId INTEGER, targetLineId INTEGER, targetLineIndex INTEGER,
        targetBookOrderIndex INTEGER, connectionTypeId INTEGER, baseProvenance INTEGER);
      CREATE TABLE link_anchor (linkId INTEGER, side INTEGER, charStart INTEGER,
        charEnd INTEGER, label TEXT, spans TEXT, PRIMARY KEY (linkId, side, charStart));
      CREATE TABLE link_range (linkId INTEGER, side INTEGER, endLineId INTEGER,
        endLineIndex INTEGER, PRIMARY KEY (linkId, side));
      CREATE TABLE link_coverage (lineId INTEGER, linkId INTEGER, side INTEGER,
        PRIMARY KEY (lineId, linkId, side));

      INSERT INTO category VALUES (1,NULL,'cat',0,1,NULL,NULL);
      INSERT INTO source VALUES (1,'Sefaria');
      INSERT INTO book VALUES (1,1,1,'A','A',NULL,NULL,1,1,2,0,0,0,NULL,NULL,NULL),
                             (2,1,1,'B','B',NULL,NULL,2,0,1,0,0,0,NULL,NULL,NULL);
      INSERT INTO line VALUES (1,1,0,'a1','A 1',NULL,2),(2,1,1,'a2','A 2',NULL,2),
                              (3,2,0,'b1','B 1',NULL,2);
      INSERT INTO connection_type VALUES (1,'OTHER'),(2,'COMMENTARY');
      INSERT INTO link VALUES (1,1,2,1,3,0,2,1,0),(2,1,2,1,3,0,2,1,0),(3,1,2,1,3,0,2,2,0);
      -- link 1 משתרע על שתי שורות של A: השורה השנייה מגיעה דרך coverage
      INSERT INTO link_range VALUES (1,0,2,1);
      INSERT INTO link_coverage VALUES (2,1,0);
    ''');
    if (withTable) {
      db.execute(
        'CREATE TABLE link_suppressed_side (linkId INTEGER NOT NULL, '
        'side INTEGER NOT NULL, reasonMask INTEGER NOT NULL, '
        'PRIMARY KEY (linkId, side))',
      );
      if (populate) {
        db.execute('INSERT INTO link_suppressed_side VALUES (1,0,4)');
      }
    }
    db.close();
    return path;
  }

  /// מזהי הקישורים שהשאילתה הקדמית מחזירה עבור ספר הבסיס A.
  Set<int> forwardTargets(String path) =>
      DatabaseLibraryProvider.loadBookLinksRowsForTesting(
            dbPath: path,
            title: 'A',
            categoryId: 1,
            fileType: 'text',
          )
          .where((r) => r['connectionTypeName'] != 'SOURCE')
          .map((r) => r['sourceLineIndex'] as int)
          .toSet();

  /// שורות שהספר המצטג B מקבל — כלומר הזרוע ההפוכה.
  List<Map<String, dynamic>> inverseRows(String path) =>
      DatabaseLibraryProvider.loadBookLinksRowsForTesting(
        dbPath: path,
        title: 'B',
        categoryId: 1,
        fileType: 'text',
      ).toList();

  setUp(() => tmp = Directory.systemTemp.createTempSync('linkvis'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('מסד ישן (אין טבלה) — התנהגות קודמת', () {
    test('הזרוע ההפוכה מחזירה רק תלויי-טקסט, מתויגים SOURCE', () {
      final rows = inverseRows(buildDb(withTable: false));
      expect(rows.map((r) => r['connectionTypeName']).toSet(), {'SOURCE'});
    });

    test('הקדמית מחזירה את כל שלושת הקישורים, כולל שורת ה-coverage', () {
      // שתי שורות של A: 0 (העוגן) ו-1 (מכוסה) עבור link 1.
      expect(forwardTargets(buildDb(withTable: false)), {0, 1});
    });
  });

  group('טבלה ריקה — שקולה תוצאתית לחסרה', () {
    test('אותן שורות בדיוק כמו מסד ישן', () {
      final empty = inverseRows(buildDb(withTable: true, populate: false));
      final missing = inverseRows(buildDb(withTable: false));
      expect(empty.length, missing.length);
      expect(
        empty.map((r) => r['connectionTypeName']).toSet(),
        missing.map((r) => r['connectionTypeName']).toSet(),
      );
    });
  });

  group('סכמה 3 — הקישור עובר צד', () {
    test('נעלם מספר הבסיס, כולל שורת ה-coverage שלו', () {
      // link 1 דוכא בצד 0 → גם העוגן וגם השורה המכוסה נעלמים; link 2/3 נשארים.
      expect(forwardTargets(buildDb(withTable: true)), {0});
    });

    test('מופיע בספר המצטג, ומתויג בסוגו האמיתי ולא כ-SOURCE', () {
      final rows = inverseRows(buildDb(withTable: true));
      final types = rows.map((r) => r['connectionTypeName']).toList();
      expect(
        types,
        containsAll(['OTHER', 'SOURCE']),
        reason: 'המועבר שומר OTHER; תלוי-הטקסט נשאר SOURCE',
      );
      // link 2 גלוי מהצד הקדמי ולכן אינו מוכפל לכאן.
      expect(types.where((t) => t == 'OTHER').length, 1);
    });

    test('טווח הפרק נשמר על הקישור המועבר', () {
      final moved = inverseRows(
        buildDb(withTable: true),
      ).firstWhere((r) => r['connectionTypeName'] == 'OTHER');
      expect(moved['targetRangeEndLineIndex'], 1);
    });
  });

  group('שברי ה-SQL', () {
    test('ריקים כשאין תמיכה — לא נפלט SQL', () {
      expect(suppressedSideFilter(false, displayedSide: 0), '');
      expect(
        inverseScopeFilter(false, LinkTypes.dependentTextTypes.toList()),
        '',
      );
    });
  });
}
