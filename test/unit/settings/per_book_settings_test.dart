import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/app_paths.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/settings/services/per_book_settings_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('TextBookPerBookSettings JSON', () {
    test('round-trip שומר את כל השדות כולל continuousReadingMode', () {
      final original = TextBookPerBookSettings(
        fontSize: 22.5,
        commentatorsBelow: true,
        removeNikud: false,
        removePunctuation: true,
        continuousReadingMode: true,
      );

      final restored = TextBookPerBookSettings.fromJson(original.toJson());

      expect(restored.fontSize, 22.5);
      expect(restored.commentatorsBelow, isTrue);
      expect(restored.removeNikud, isFalse);
      expect(restored.removePunctuation, isTrue);
      expect(restored.continuousReadingMode, isTrue);
    });

    test('toJson משמיט שדות null', () {
      final settings = TextBookPerBookSettings(continuousReadingMode: true);
      final json = settings.toJson();

      expect(json.containsKey('continuousReadingMode'), isTrue);
      expect(json.containsKey('fontSize'), isFalse);
      expect(json.containsKey('commentatorsBelow'), isFalse);
      expect(json.containsKey('removeNikud'), isFalse);
      expect(json.containsKey('removePunctuation'), isFalse);
    });

    test('fromJson עם שדה חסר מחזיר null עבור continuousReadingMode', () {
      // תאימות לאחור: הגדרות שנשמרו לפני הפיצ'ר אינן מכילות את השדה.
      final restored = TextBookPerBookSettings.fromJson({
        'fontSize': 18.0,
        'removeNikud': true,
      });
      expect(restored.continuousReadingMode, isNull);
      expect(restored.fontSize, 18.0);
      expect(restored.removeNikud, isTrue);
    });

    test('round-trip שומר את רוחבי הטורים בצורת הדף', () {
      final original = TextBookPerBookSettings(
        pageShapeLeftWidth: 240.5,
        pageShapeRightWidth: 180.0,
        pageShapeBottomHeight: 300.0,
        pageShapeBottomLeftWidth: 400.0,
      );

      final restored = TextBookPerBookSettings.fromJson(original.toJson());

      expect(restored.pageShapeLeftWidth, 240.5);
      expect(restored.pageShapeRightWidth, 180.0);
      expect(restored.pageShapeBottomHeight, 300.0);
      expect(restored.pageShapeBottomLeftWidth, 400.0);
    });

    test('toJson משמיט רוחבי טורים null', () {
      final settings = TextBookPerBookSettings(pageShapeLeftWidth: 100.0);
      final json = settings.toJson();

      expect(json.containsKey('pageShapeLeftWidth'), isTrue);
      expect(json.containsKey('pageShapeRightWidth'), isFalse);
      expect(json.containsKey('pageShapeBottomHeight'), isFalse);
      expect(json.containsKey('pageShapeBottomLeftWidth'), isFalse);
    });

    test('fromJson מקבל גם ערכי רוחב שלמים (int) מ-JSON', () {
      // הגנה מפני ערכים שנשמרו כ-int (JSON אינו מבחין בין int ל-double).
      final restored = TextBookPerBookSettings.fromJson({
        'pageShapeLeftWidth': 200,
        'pageShapeBottomHeight': 250,
      });
      expect(restored.pageShapeLeftWidth, 200.0);
      expect(restored.pageShapeBottomHeight, 250.0);
      expect(restored.pageShapeRightWidth, isNull);
    });

    test('copyWith משמר שדות קיימים ומעדכן רק את שניתנו', () {
      final base = TextBookPerBookSettings(
        fontSize: 20.0,
        removeNikud: true,
        pageShapeLeftWidth: 100.0,
      );

      // עדכון רק רוחבי הטורים - שאר השדות נשמרים
      final updated = base.copyWith(
        pageShapeLeftWidth: 150.0,
        pageShapeRightWidth: 90.0,
      );

      expect(updated.fontSize, 20.0);
      expect(updated.removeNikud, isTrue);
      expect(updated.pageShapeLeftWidth, 150.0);
      expect(updated.pageShapeRightWidth, 90.0);
      expect(updated.pageShapeBottomHeight, isNull);
    });

    test('round-trip שומר את רשימת המפרשים הנבחרים', () {
      final original = TextBookPerBookSettings(
        activeCommentators: const ['רש"י', 'תוספות'],
      );

      final restored = TextBookPerBookSettings.fromJson(original.toJson());

      expect(restored.activeCommentators, ['רש"י', 'תוספות']);
    });

    test('רשימת מפרשים ריקה שורדת round-trip (בחירה שבוטלה)', () {
      // בחירה ריקה היא מצב מכוון (המשתמש הסיר את כל המפרשים) ולכן נשמרת
      // ולא נחשבת כ-null.
      final settings = TextBookPerBookSettings(activeCommentators: const []);
      final json = settings.toJson();
      expect(json.containsKey('activeCommentators'), isTrue);

      final restored = TextBookPerBookSettings.fromJson(json);
      expect(restored.activeCommentators, isEmpty);
    });

    test('toJson משמיט activeCommentators כשהוא null', () {
      final settings = TextBookPerBookSettings(fontSize: 18.0);
      expect(settings.toJson().containsKey('activeCommentators'), isFalse);
    });

    test('copyWith משמר את activeCommentators כשלא ניתן', () {
      final base = TextBookPerBookSettings(activeCommentators: const ['רש"י']);
      final updated = base.copyWith(fontSize: 20.0);
      expect(updated.activeCommentators, ['רש"י']);
      expect(updated.fontSize, 20.0);
    });

    test('continuousReadingMode=false שורד round-trip', () {
      // toJson משמיט רק null (לא false). אם בעתיד מישהו ירצה לשמור
      // false במפורש — הוא חייב לעבוד. _savePerBookSettingsDirectly
      // הוא זה שמחליט אם להמיר false ל-null (אופטימיזציה של אחסון),
      // לא ה-JSON עצמו.
      final settings = TextBookPerBookSettings(continuousReadingMode: false);
      final json = settings.toJson();
      expect(json['continuousReadingMode'], isFalse);

      final restored = TextBookPerBookSettings.fromJson(json);
      expect(restored.continuousReadingMode, isFalse);
    });
  });

  group('PerBookSettings.bookKey — מפתח ייחודי לספר', () {
    test('ספר אישי וספר רשמי באותו שם מקבלים מפתחות נפרדים', () {
      final official = TextBook(title: 'ספר', categoryId: 1);
      final user = TextBook(title: 'ספר', categoryId: 1, isUserBook: true);

      expect(PerBookSettings.bookKey(official),
          isNot(PerBookSettings.bookKey(user)));
    });

    test('שני ספרי טקסט באותו שם בקטגוריות שונות נפרדים', () {
      final a = TextBook(title: 'ספר', categoryId: 1);
      final b = TextBook(title: 'ספר', categoryId: 2);

      expect(PerBookSettings.bookKey(a), isNot(PerBookSettings.bookKey(b)));
    });

    test('ספרי PDF באותו שם בנתיבים שונים נפרדים (מפתוח לפי path)', () {
      final a = PdfBook(title: 'ספר', path: '/a/book.pdf');
      final b = PdfBook(title: 'ספר', path: '/b/book.pdf');

      expect(PerBookSettings.bookKey(a), isNot(PerBookSettings.bookKey(b)));
    });

    test('נתיבים שונים בעלי sanitize זהה עדיין נפרדים (a_b מול a/b)', () {
      // ללא hash, _sanitizeBookName היה ממיר את שניהם לאותו שם קובץ.
      final a = PdfBook(title: 'ספר', path: r'C:\library\a_b.pdf');
      final b = PdfBook(title: 'ספר', path: r'C:\library\a\b.pdf');

      expect(PerBookSettings.bookKey(a), isNot(PerBookSettings.bookKey(b)));
    });

    test('אותו ספר מחזיר מפתח יציב', () {
      final book = TextBook(title: 'ספר', categoryId: 1);
      expect(
          PerBookSettings.bookKey(book), equals(PerBookSettings.bookKey(book)));
    });
  });

  group('PdfBookPerBookSettings — שמירה/טעינה בפועל', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('per_book_test');
      AppPaths.debugOverrideDataRootPath(tempDir.path);
    });

    tearDown(() async {
      AppPaths.debugOverrideDataRootPath(null);
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    Future<File> writeLegacy(String title, Map<String, dynamic> json) async {
      final dir = Directory(p.join(tempDir.path, 'per_book_settings'));
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'settings_$title.json'));
      await file.writeAsString(jsonEncode(json));
      return file;
    }

    test('שני נתיבים בעלי sanitize זהה נשמרים ונטענים בנפרד', () async {
      final a = PdfBook(title: 'ספר', path: r'C:\library\a_b.pdf');
      final b = PdfBook(title: 'ספר', path: r'C:\library\a\b.pdf');

      await PdfBookPerBookSettings(zoom: 1.5).save(a);
      await PdfBookPerBookSettings(zoom: 2.5).save(b);

      expect((await PdfBookPerBookSettings.load(a))?.zoom, 1.5);
      expect((await PdfBookPerBookSettings.load(b))?.zoom, 2.5);
    });

    test('שני ספרים באותו שם יורשים legacy; איפוס אחד לא פוגע באחר', () async {
      await writeLegacy('ספר', {'zoom': 3.0});

      final a = PdfBook(title: 'ספר', path: '/a/ספר.pdf');
      final b = PdfBook(title: 'ספר', path: '/b/ספר.pdf');

      // שניהם יורשים את ה-legacy (copy, לא rename)
      expect((await PdfBookPerBookSettings.load(a))?.zoom, 3.0);
      expect((await PdfBookPerBookSettings.load(b))?.zoom, 3.0);

      // איפוס a — b עדיין שומר את ההגדרה הישנה (ה-legacy לא נמחק)
      await PdfBookPerBookSettings.delete(a);
      expect((await PdfBookPerBookSettings.load(a))?.zoom, isNull);
      expect((await PdfBookPerBookSettings.load(b))?.zoom, 3.0);
    });

    test('איפוס אינו "מתחייה" בפתיחה הבאה (tombstone)', () async {
      await writeLegacy('ספר', {'zoom': 4.0});
      final a = PdfBook(title: 'ספר', path: '/a/ספר.pdf');

      expect((await PdfBookPerBookSettings.load(a))?.zoom, 4.0);
      await PdfBookPerBookSettings.delete(a);
      // טעינה חוזרת לא משחזרת מ-legacy
      expect((await PdfBookPerBookSettings.load(a))?.zoom, isNull);
    });
  });
}
