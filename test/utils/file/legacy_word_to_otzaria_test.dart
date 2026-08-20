import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/document_conversion_exceptions.dart';
import 'package:otzaria/utils/file/document_converter.dart';
import 'package:otzaria/utils/file/document_format.dart';
import 'package:otzaria/utils/file/legacy_word_to_otzaria.dart';
import 'package:otzaria/utils/file/toc_parser.dart';
import 'package:path/path.dart' as p;

import 'cfb_fixtures.dart';

// ─── עזרי בנייה ──────────────────────────────────────────────────────────

Uint8List buildDoc(
  List<WordPiece> pieces, {
  bool encrypted = false,
  bool useTable1 = true,
  int wIdent = 0xA5EC,
  int nFib = 193,
  int? ccpTextOverride,
  bool omitClx = false,
  bool omitTableStream = false,
}) => buildWordBinary(
  pieces,
  encrypted: encrypted,
  useTable1: useTable1,
  wIdent: wIdent,
  nFib: nFib,
  ccpTextOverride: ccpTextOverride,
  omitClx: omitClx,
  omitTableStream: omitTableStream,
);

String para(String text) => '$text\r';

/// שכבת המאפיינים והערות השוליים אומתו מול שישה מסמכי Word אמיתיים בעברית
/// (ראו `docs/legacy_word_doc_research.md`). הבדיקות כאן מקבעות את החוזה
/// שנגזר מהם: בלי השכבה הזו הפלט היה טקסט חשוף — בלי כותרות, בלי תוכן
/// עניינים, בלי עיצוב ובלי הערות.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String convert(Uint8List bytes, [String title = 'ספר']) =>
      legacyWordToText(bytes, title);

  group('חילוץ טקסט', () {
    test('פסקה אחת ב-UTF-16 (המסלול של עברית)', () {
      final out = convert(buildDoc([WordPiece(para('שלום עולם'))]));
      expect(out, '<h1>ספר</h1>\nשלום עולם');
    });

    test('כמה פסקאות', () {
      final out = convert(
        buildDoc([
          WordPiece(para('פסקה ראשונה') + para('פסקה שנייה')),
        ]),
      );
      expect(out, '<h1>ספר</h1>\nפסקה ראשונה\nפסקה שנייה');
    });

    test('חתיכה דחוסה (cp1252) מפוענחת נכון', () {
      final out = convert(
        buildDoc([WordPiece(para('Hello World'), compressed: true)]),
      );
      expect(out, '<h1>ספר</h1>\nHello World');
    });

    test('חתיכות מעורבות מורכבות לפי הסדר הלוגי', () {
      // הליבה של הפורמט: אנגלית נדחסת, עברית לא — ורק ה-piece table
      // יודע להרכיב את שתיהן לרצף אחד.
      final out = convert(
        buildDoc([
          const WordPiece('English ', compressed: true),
          WordPiece(para('ועברית')),
        ]),
      );
      expect(out, '<h1>ספר</h1>\nEnglish ועברית');
    });

    test('סדר החתיכות נקבע ב-piece table ולא בסדר הפיזי', () {
      final out = convert(
        buildDoc([
          const WordPiece('אחת ', compressed: false),
          const WordPiece('שתיים ', compressed: false),
          WordPiece(para('שלוש')),
        ]),
      );
      expect(out, '<h1>ספר</h1>\nאחת שתיים שלוש');
    });

    test('בית גבוה בחתיכה דחוסה ממופה לפי cp1252', () {
      // 0x93 הוא גרש-פתיחה טיפוגרפי ב-cp1252, לא תו בקרה.
      final out = convert(
        buildDoc([
          WordPiece('${String.fromCharCode(0x93)}quote\r', compressed: true),
        ]),
      );
      expect(out, contains('\u201C'));
    });
  });

  group('גבול גוף המסמך', () {
    test('טקסט מעבר ל-ccpText (הערות שוליים) אינו נכלל', () {
      final bytes = buildDoc(
        [WordPiece(para('גוף') + para('הערת שוליים'))],
        ccpTextOverride: 'גוף\r'.length,
      );
      final out = convert(bytes);

      expect(out, '<h1>ספר</h1>\nגוף');
      expect(out, isNot(contains('הערת שוליים')));
    });

    test('חיתוך באמצע חתיכה', () {
      final bytes = buildDoc(
        [WordPiece(para('אבגדה'))],
        ccpTextOverride: 3,
      );
      expect(convert(bytes), '<h1>ספר</h1>\nאבג');
    });
  });

  group('תווי בקרה של Word', () {
    test('מעבר שורה רך הופך ל-<br>', () {
      final out = convert(
        buildDoc([WordPiece('ראשונה${String.fromCharCode(0x0B)}שנייה\r')]),
      );
      expect(out, '<h1>ספר</h1>\nראשונה<br>שנייה');
    });

    test('סוף תא ומעבר עמוד מסיימים פסקה', () {
      final cellEnd = String.fromCharCode(0x07);
      final pageBreak = String.fromCharCode(0x0C);
      final out = convert(
        buildDoc([
          WordPiece(
            'תא$cellEnd'
            'עמוד$pageBreak'
            'אחרי\r',
          ),
        ]),
      );
      expect(out, '<h1>ספר</h1>\nתא\nעמוד\nאחרי');
    });

    test('הוראת שדה מושמטת והתוצאה נשמרת', () {
      final begin = String.fromCharCode(0x13);
      final separator = String.fromCharCode(0x14);
      final end = String.fromCharCode(0x15);
      final out = convert(
        buildDoc([
          WordPiece(
            'לפני $begin HYPERLINK "http://x" $separator טקסט$end אחרי\r',
          ),
        ]),
      );

      expect(out, contains('טקסט'));
      expect(out, isNot(contains('HYPERLINK')));
      expect(out, contains('לפני'));
      expect(out, contains('אחרי'));
    });

    test('סימוני תמונה ואובייקט אינם נפלטים כתווי זבל', () {
      final picture = String.fromCharCode(0x01);
      final drawing = String.fromCharCode(0x08);
      final out = convert(
        buildDoc([WordPiece('טקסט$picture$drawing נקי\r')]),
      );
      expect(out, '<h1>ספר</h1>\nטקסט נקי');
    });

    test('מקף אופציונלי מושמט ומקף קשיח נשמר', () {
      final optional = String.fromCharCode(0x1F);
      final nonBreaking = String.fromCharCode(0x1E);
      final out = convert(
        buildDoc([
          WordPiece(
            'א$optional'
            'ב$nonBreaking'
            'ג\r',
          ),
        ]),
      );
      expect(out, '<h1>ספר</h1>\nאב-ג');
    });

    test('פסקה ריקה אינה נוספת לפלט', () {
      final out = convert(
        buildDoc([WordPiece('\r\r  \rתוכן\r')]),
      );
      expect(out, '<h1>ספר</h1>\nתוכן');
    });

    test('טאב נשמר', () {
      final out = convert(buildDoc([WordPiece('א\tב\r')]));
      expect(out, contains('א\tב'));
    });
  });

  group('כותרת ו-escape', () {
    test('הכותרת מוזרקת כ-h1 בשורה 0', () {
      final out = convert(buildDoc([WordPiece(para('תוכן'))]), 'שם מהקטלוג');
      expect(out.split('\n').first, '<h1>שם מהקטלוג</h1>');
    });

    test('תווי HTML בכותרת ובתוכן עוברים escape', () {
      final out = convert(buildDoc([WordPiece(para('a < b & c'))]), 'א<b>&');
      expect(out.split('\n').first, '<h1>א&lt;b&gt;&amp;</h1>');
      expect(out, contains('a &lt; b &amp; c'));
    });

    test('<br> אינו הופך ל-entity', () {
      final out = convert(
        buildDoc([WordPiece('א${String.fromCharCode(0x0B)}<b>\r')]),
      );
      expect(out, contains('<br>'));
      expect(out, contains('&lt;b&gt;'));
    });
  });

  group('בחירת זרם הטבלה', () {
    test('fWhichTblStm=1 קורא מ-1Table', () {
      final out = convert(
        buildDoc([WordPiece(para('מטבלה 1'))], useTable1: true),
      );
      expect(out, contains('מטבלה 1'));
    });

    test('fWhichTblStm=0 קורא מ-0Table', () {
      final out = convert(
        buildDoc([WordPiece(para('מטבלה 0'))], useTable1: false),
      );
      expect(out, contains('מטבלה 0'));
    });
  });

  group('שגיאות מוקלדות', () {
    test('מסמך מוצפן זורק EncryptedDocumentException', () {
      expect(
        () => convert(buildDoc([WordPiece(para('סודי'))], encrypted: true)),
        throwsA(isA<EncryptedDocumentException>()),
      );
    });

    test('Word 6/95 נדחה מפורשות ואינו מנסה לפרסר', () {
      expect(
        () => convert(buildDoc([WordPiece(para('ישן'))], wIdent: 0xA5DC)),
        throwsA(isA<UnsupportedDocumentFormatException>()),
      );
    });

    test('גרסת FIB ישנה מדי נדחית', () {
      expect(
        () => convert(buildDoc([WordPiece(para('ישן'))], nFib: 100)),
        throwsA(isA<UnsupportedDocumentFormatException>()),
      );
    });

    test('חוסר piece table זורק CorruptedDocumentException', () {
      expect(
        () => convert(buildDoc([WordPiece(para('x'))], omitClx: true)),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('זרם טבלה חסר זורק CorruptedDocumentException', () {
      expect(
        () => convert(buildDoc([WordPiece(para('x'))], omitTableStream: true)),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('מכולה שאינה Word זורקת', () {
      final bytes = CfbBuilder({
        'Workbook': Uint8List.fromList([1, 2, 3]),
      }).build();
      expect(
        () => convert(bytes),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('קלט שאינו CFB זורק', () {
      expect(
        () => convert(Uint8List.fromList('סתם טקסט'.codeUnits)),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('החריגה נושאת את הפורמט ואת הנתיב', () {
      try {
        legacyWordToText(
          buildDoc([WordPiece(para('סודי'))], encrypted: true),
          'ספר',
          format: DocumentFormat.dot,
          path: 'C:/ספרים/תבנית.dot',
        );
        fail('הייתה אמורה להיזרק חריגה');
      } on EncryptedDocumentException catch (e) {
        expect(e.format, DocumentFormat.dot);
        expect(e.path, 'C:/ספרים/תבנית.dot');
      }
    });
  });

  group('יציבות', () {
    test('המרה חוזרת דטרמיניסטית', () {
      final bytes = buildDoc([
        const WordPiece('English ', compressed: true),
        WordPiece(para('ועברית')),
      ]);
      expect(convert(bytes), convert(bytes));
    });

    test('מסמך גדול מומר במלואו', () {
      final buffer = StringBuffer();
      for (var i = 0; i < 2000; i++) {
        buffer.write(para('שורה $i'));
      }
      final out = convert(buildDoc([WordPiece(buffer.toString())]));
      expect(out.split('\n').length, 2001);
      expect(out, contains('שורה 1999'));
    });

    test('DOT (תבנית) נקרא כמו DOC', () {
      final out = legacyWordToText(
        buildDoc([WordPiece(para('תוכן תבנית'))]),
        'תבנית',
        format: DocumentFormat.dot,
      );
      expect(out, '<h1>תבנית</h1>\nתוכן תבנית');
    });
  });

  // §56: WBK הוא גיבוי שיכול להיות כל אחד משני המנועים — הסיומת אינה
  // מסגירה אותו, ורק זיהוי התוכן מכריע.
  group('ניתוב WBK דרך הצנרת המלאה', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wbk-routing-');
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } on FileSystemException {
        // נעילת קובץ ב-Windows אינה מעניינה של הבדיקה.
      }
    });

    test('WBK שתוכנו Word בינארי מנותב למנוע הישן', () async {
      final file = File(p.join(tempDir.path, 'גיבוי.wbk'));
      await file.writeAsBytes(buildDoc([WordPiece(para('תוכן מגיבוי'))]));

      final text = await readFileBackedBookText(file, 'wbk', 'גיבוי');

      expect(text, '<h1>גיבוי</h1>\nתוכן מגיבוי');
    });

    test('DOC אמיתי עובר את אותה צנרת', () async {
      final file = File(p.join(tempDir.path, 'ספר.doc'));
      await file.writeAsBytes(
        buildDoc([
          const WordPiece('English ', compressed: true),
          WordPiece(para('ועברית')),
        ]),
      );

      final text = await readFileBackedBookText(file, 'doc', 'ספר');

      expect(text, '<h1>ספר</h1>\nEnglish ועברית');
    });

    test('עריכת הקובץ מייצרת המרה מחדש (תוקף המטמון)', () async {
      final file = File(p.join(tempDir.path, 'נערך.doc'));
      await file.writeAsBytes(buildDoc([WordPiece(para('גרסה ראשונה'))]));
      expect(
        await readFileBackedBookText(file, 'doc', 'נערך'),
        contains('גרסה ראשונה'),
      );

      await file.writeAsBytes(buildDoc([WordPiece(para('גרסה שנייה'))]));

      final updated = await readFileBackedBookText(file, 'doc', 'נערך');
      expect(updated, contains('גרסה שנייה'));
      expect(updated, isNot(contains('גרסה ראשונה')));
    });

    test('תוכן עניינים נבנה מהמסמך הישן', () async {
      final file = File(p.join(tempDir.path, 'עם-כותרת.doc'));
      // הממיר מחלץ טקסט בלבד; כותרת הספר היא מקור ה-TOC בשלב זה.
      await file.writeAsBytes(buildDoc([WordPiece(para('גוף'))]));

      final content = await convertDocumentForIndex(
        file,
        'שם הספר',
        DocumentFormat.doc,
      );
      final toc = TocParser.parseEntriesFromContent(content);

      expect(toc.map((e) => e.text), contains('שם הספר'));
    });
  });
}
