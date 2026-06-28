import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library_update/services/logical_content_hasher.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

const _hasher = LogicalContentHasher();

void main() {
  group('LogicalContentHasher invariants', () {
    test('סדר הכנסה פיזי שונה → אותו hash (בזכות ORDER BY id)', () {
      final a = sqlite3.sqlite3.openInMemory();
      final b = sqlite3.sqlite3.openInMemory();
      for (final db in [a, b]) {
        db.execute('CREATE TABLE source (id INTEGER PRIMARY KEY, name TEXT)');
      }
      a.execute("INSERT INTO source VALUES (1,'aleph'),(2,'bet'),(3,'gimel')");
      b.execute("INSERT INTO source VALUES (3,'gimel'),(1,'aleph'),(2,'bet')");

      expect(_hasher.compute(a), _hasher.compute(b));
      a.close();
      b.close();
    });

    test('שינוי ערך בשורה → hash שונה', () {
      final a = sqlite3.sqlite3.openInMemory();
      final b = sqlite3.sqlite3.openInMemory();
      for (final db in [a, b]) {
        db.execute('CREATE TABLE source (id INTEGER PRIMARY KEY, name TEXT)');
        db.execute("INSERT INTO source VALUES (1,'aleph'),(2,'bet')");
      }
      b.execute("UPDATE source SET name='changed' WHERE id=2");

      expect(_hasher.compute(a), isNot(_hasher.compute(b)));
      a.close();
      b.close();
    });

    test('סוגי null/int/text/blob מקודדים — שינוי סוג משנה hash', () {
      final a = sqlite3.sqlite3.openInMemory();
      final b = sqlite3.sqlite3.openInMemory();
      for (final db in [a, b]) {
        db.execute('CREATE TABLE source (id INTEGER PRIMARY KEY, v)');
      }
      // ב-a הערך הוא טקסט "1", ב-b הוא מספר 1 — צריך hash שונה (type tag).
      a.execute("INSERT INTO source VALUES (1,'1')");
      b.execute('INSERT INTO source VALUES (1,1)');
      expect(_hasher.compute(a), isNot(_hasher.compute(b)));
      a.close();
      b.close();
    });

    test('טבלה חסרה אינה מפילה את החישוב', () {
      final db = sqlite3.sqlite3.openInMemory();
      db.execute('CREATE TABLE source (id INTEGER PRIMARY KEY, name TEXT)');
      db.execute("INSERT INTO source VALUES (1,'x')");
      // שאר הטבלאות ב-kHashTableOrder חסרות — אסור שזה יזרוק.
      expect(() => _hasher.compute(db), returnsNormally);
      db.close();
    });
  });

  // אימות מול ה-DBs האמיתיים — ה-ground truth מול מימוש ה-Kotlin.
  // מדלג אם הקבצים אינם זמינים (CI). ריצה מקומית מאמתת התאמה מלאה.
  group('LogicalContentHasher against real DBs', () {
    const releasesDir = '/Users/david/Downloads/releases';
    const cases = [
      (
        'v1',
        '35d499985cc1c37fd02904682d4f67a8c915625ef3768c0e856d3f79a4fc96c1'
      ),
      (
        'v2',
        '2be5318d73e4ffa6b32c5d265699e6000cd84f776c304db4a9b192e7d67b3d06'
      ),
      (
        'v3',
        'adb131e748347b1b1f0d3407ee99cddae6d6d18e0a40078176b17cd68d6ff9cf'
      ),
    ];

    for (final (version, expected) in cases) {
      final path = '$releasesDir/$version/seforim.db';
      test('hash($version) == content hash', () {
        final db = sqlite3.sqlite3.open(path, mode: sqlite3.OpenMode.readOnly);
        try {
          expect(_hasher.compute(db), expected);
        } finally {
          db.close();
        }
      },
          skip: File(path).existsSync()
              ? false
              : 'קובץ ה-DB של $version אינו זמין',
          timeout: const Timeout(Duration(minutes: 4)));
    }
  });
}
