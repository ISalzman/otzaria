import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/file/document_conversion_exceptions.dart';
import 'package:otzaria/utils/file/document_converter.dart';
import 'package:path/path.dart' as p;

/// [readFileBackedBookText] בוחרת ממיר לפי סוג הקובץ. הרגרסיה שהיא מונעת:
/// `readAsString` על DOCX/EPUB (ZIP בינארי) זורק `FileSystemException`,
/// והקוראים בלעו אותו והמשיכו עם תוכן ריק.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file-backed-book-text-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Uint8List buildDocxBytes(String paragraph) {
    final xml = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body><w:p><w:r><w:t>$paragraph</w:t></w:r></w:p></w:body>'
      '</w:document>',
    );
    final archive = Archive()
      ..addFile(ArchiveFile('word/document.xml', xml.length, xml));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<File> writeDocx(String name, String paragraph) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsBytes(buildDocxBytes(paragraph));
    return file;
  }

  Future<File> writeEpub(String name, String bodyText) async {
    const containerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0"
    xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf"
        media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
    const opf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0"
    unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">test-book</dc:identifier>
  </metadata>
  <manifest>
    <item id="c0" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="c0"/></spine>
</package>''';
    final chapter =
        '''
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>פרק</title></head>
<body><p>$bodyText</p></body>
</html>''';

    final archive = Archive();
    void addText(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    addText('META-INF/container.xml', containerXml);
    addText('OEBPS/content.opf', opf);
    addText('OEBPS/ch1.xhtml', chapter);

    final file = File(p.join(tempDir.path, name));
    await file.writeAsBytes(Uint8List.fromList(ZipEncoder().encode(archive)));
    return file;
  }

  group('DOCX', () {
    test('מומר לטקסט ולא נקרא כמחרוזת UTF-8', () async {
      final file = await writeDocx('ספר.docx', 'ויאמר אלהים יהי אור');

      // הראיה שהמסלול הישן שבור: אותו קובץ בדיוק זורק בקריאה כטקסט.
      await expectLater(
        file.readAsString(),
        throwsA(isA<FileSystemException>()),
      );

      final text = await readFileBackedBookText(file, 'docx', 'ספר');

      expect(text, contains('ויאמר אלהים יהי אור'));
      expect(text, contains('<h1>ספר</h1>'));
    });

    test('הכותרת מוזרקת מהפרמטר ולא משם הקובץ', () async {
      final file = await writeDocx('שם-קובץ.docx', 'תוכן');

      final text = await readFileBackedBookText(file, 'docx', 'שם הספר בקטלוג');

      expect(text, contains('<h1>שם הספר בקטלוג</h1>'));
      expect(text, isNot(contains('שם-קובץ')));
    });

    test('fileType באותיות גדולות מזוהה', () async {
      final file = await writeDocx('גדול.docx', 'תוכן באותיות גדולות');

      final text = await readFileBackedBookText(file, 'DOCX', 'גדול');

      expect(text, contains('תוכן באותיות גדולות'));
    });

    test('סיומת באותיות גדולות מזוהה כש-fileType חסר', () async {
      final file = await writeDocx('סיומת.DOCX', 'תוכן מסיומת גדולה');

      final text = await readFileBackedBookText(file, null, 'סיומת');

      expect(text, contains('תוכן מסיומת גדולה'));
    });
  });

  group('EPUB', () {
    test('מומר לטקסט ולא נקרא כמחרוזת UTF-8', () async {
      final file = await writeEpub('ספר.epub', 'בראשית ברא אלהים');

      await expectLater(
        file.readAsString(),
        throwsA(isA<FileSystemException>()),
      );

      final text = await readFileBackedBookText(file, 'epub', 'ספר');

      expect(text, contains('בראשית ברא אלהים'));
    });

    test('סוג נגזר מהסיומת כש-fileType חסר', () async {
      final file = await writeEpub('ללא-סוג.epub', 'טקסט מן האפאב');

      final text = await readFileBackedBookText(file, null, 'ללא סוג');

      expect(text, contains('טקסט מן האפאב'));
    });
  });

  group('גזירת הסוג', () {
    test('fileType ריק נופל לסיומת', () async {
      final file = await writeDocx('ריק.docx', 'שורה מן הקובץ');

      final text = await readFileBackedBookText(file, '', 'ריק');

      expect(text, contains('שורה מן הקובץ'));
    });

    test('fileType מפורש גובר על סיומת מטעה', () async {
      // הקובץ הוא DOCX תקין אך נשמר עם סיומת txt — כפי שקורה לספרים
      // שהמשתמש שינה להם את השם. fileType מה-DB הוא מקור האמת.
      final file = File(p.join(tempDir.path, 'מוסווה.txt'));
      await file.writeAsBytes(buildDocxBytes('תוכן שהוסווה'));

      final text = await readFileBackedBookText(file, 'docx', 'מוסווה');

      expect(text, contains('תוכן שהוסווה'));
    });

    test('קובץ ללא סיומת נקרא כטקסט', () async {
      final file = File(p.join(tempDir.path, 'ללא_סיומת'));
      await file.writeAsString('טקסט חשוף');

      expect(
        await readFileBackedBookText(file, null, 'ללא סיומת'),
        'טקסט חשוף',
      );
    });

    test('Markdown מומר ל-HTML ולא מוחזר כמקור', () async {
      final file = File(p.join(tempDir.path, 'ספר.md'));
      await file.writeAsString('# כותרת');

      final text = await readFileBackedBookText(file, 'md', 'ספר');

      expect(text, contains('כותרת'));
      expect(text, contains('<h1'));
    });

    test('סוג לא מוכר עם תוכן טקסטואלי נקרא כטקסט', () async {
      final file = File(p.join(tempDir.path, 'ספר.xyz'));
      await file.writeAsString('טקסט בסיומת לא מוכרת');

      expect(
        await readFileBackedBookText(file, 'xyz', 'ספר'),
        'טקסט בסיומת לא מוכרת',
      );
    });

    test('סיומת לא מוכרת שתוכנה DOCX מומרת ולא נקראת כטקסט', () async {
      // ההגנה המרכזית: קריאת ZIP כטקסט מייצרת ג'יבריש שנראה כספר תקין.
      final file = File(p.join(tempDir.path, 'מוסווה.xyz'));
      await file.writeAsBytes(buildDocxBytes('תוכן בינארי'));

      final text = await readFileBackedBookText(file, null, 'מוסווה');

      expect(text, contains('תוכן בינארי'));
    });

    test('סיומת לא מוכרת שתוכנה PDF מוחזרת null', () async {
      final file = File(p.join(tempDir.path, 'מוסווה2.xyz'));
      await file.writeAsBytes(const [0x25, 0x50, 0x44, 0x46, 0x2D]);

      expect(await readFileBackedBookText(file, null, 'מוסווה2'), isNull);
    });

    test('WBK שאינו Word כלל זורק חריגה מוקלדת', () async {
      // גיבוי Word חייב להיות OOXML או בינארי ישן; תוכן אחר אינו ניתן לניחוש.
      final file = File(p.join(tempDir.path, 'גיבוי.wbk'));
      await file.writeAsBytes(const [0x25, 0x50, 0x44, 0x46, 0x2D]); // %PDF-

      await expectLater(
        readFileBackedBookText(file, 'wbk', 'גיבוי'),
        throwsA(isA<UnsupportedDocumentFormatException>()),
      );
    });

    test('DOC שאינו מכולת CFB זורק חריגה מוקלדת', () async {
      final file = File(p.join(tempDir.path, 'מזויף.doc'));
      await file.writeAsString('זה בכלל לא CFB');

      await expectLater(
        readFileBackedBookText(file, 'doc', 'מזויף'),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });
  });

  // PDF מוחזר null (ולא ''), כדי שהקורא יבדיל בין "אין טקסט לפורמט הזה"
  // לבין "ספר ריק" ויוכל ליפול למסלול ה-PDF או לתוכן שב-DB.
  group('PDF', () {
    test('מוחזר null — אינו טקסט', () async {
      final file = File(p.join(tempDir.path, 'ספר.pdf'));
      await file.writeAsBytes(const [0x25, 0x50, 0x44, 0x46]);

      expect(await readFileBackedBookText(file, 'pdf', 'ספר'), isNull);
    });

    test('מוחזר null גם לפי סיומת בלבד', () async {
      final file = File(p.join(tempDir.path, 'ללא-סוג.pdf'));
      await file.writeAsBytes(const [0x25, 0x50, 0x44, 0x46]);

      expect(await readFileBackedBookText(file, null, 'ללא סוג'), isNull);
    });

    test('קובץ PDF שאינו קיים אינו זורק — הסוג נבדק לפני הקריאה', () async {
      final missing = File(p.join(tempDir.path, 'חסר.pdf'));

      expect(await readFileBackedBookText(missing, 'pdf', 'חסר'), isNull);
    });
  });

  // הממיר נכשל בקול: פלט "כותרת בלבד" נראה כספר תקין וריק, נשמר במטמון
  // ל-90 יום, נכנס לאינדקס, ומסמן כל הערה אישית שמעבר לשורה 1 כחסרה.
  group('קבצים פגומים', () {
    test('DOCX שאינו ZIP תקין זורק חריגה מוקלדת', () async {
      // קובץ טקסט ששמו .docx נכשל בקול ולא נפתח כספר ריק — כשל שקט הוא
      // הגרוע ביותר, כי המשתמש רואה ספר תקין שכל תוכנו נעלם.
      final file = File(p.join(tempDir.path, 'פגום.docx'));
      await file.writeAsString('זה בכלל לא ZIP');

      await expectLater(
        readFileBackedBookText(file, 'docx', 'פגום'),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    // ZIP בלי גוף מסמך אינו "ספר ריק": פלט כותרת-בלבד נשמר במטמון, מאונדקס,
    // ומסמן כל הערה אישית שמעבר לשורה 1 כחסרה — לצמיתות.
    test('ZIP ללא word/document.xml זורק חריגה מוקלדת', () async {
      final bytes = utf8.encode('לא מסמך');
      final archive = Archive()
        ..addFile(ArchiveFile('readme.txt', bytes.length, bytes));
      final file = File(p.join(tempDir.path, 'זיפ.docx'));
      await file.writeAsBytes(
        Uint8List.fromList(ZipEncoder().encode(archive)),
      );

      await expectLater(
        readFileBackedBookText(file, 'docx', 'זיפ'),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('DOCX ריק לגמרי (0 בתים) זורק חריגה מוקלדת', () async {
      final file = File(p.join(tempDir.path, 'ריק.docx'));
      await file.writeAsBytes(const []);

      await expectLater(
        readFileBackedBookText(file, 'docx', 'ריק'),
        throwsA(isA<CorruptedDocumentException>()),
      );
    });

    test('DOCX שאינו קיים זורק', () async {
      final missing = File(p.join(tempDir.path, 'חסר.docx'));

      await expectLater(
        readFileBackedBookText(missing, 'docx', 'חסר'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('יציבות', () {
    test('שתי קריאות לאותו קובץ מחזירות תוכן זהה', () async {
      final file = await writeDocx('חוזר.docx', 'תוכן יציב');

      final first = await readFileBackedBookText(file, 'docx', 'חוזר');
      final second = await readFileBackedBookText(file, 'docx', 'חוזר');

      expect(second, first);
    });

    test('קריאות מקבילות לאותו קובץ מחזירות תוכן זהה', () async {
      final file = await writeDocx('מקבילי.docx', 'תוכן מקבילי');

      final results = await Future.wait([
        readFileBackedBookText(file, 'docx', 'מקבילי'),
        readFileBackedBookText(file, 'docx', 'מקבילי'),
        readFileBackedBookText(file, 'docx', 'מקבילי'),
      ]);

      expect(results.toSet(), hasLength(1));
      expect(results.first, contains('תוכן מקבילי'));
    });

    test('עריכת הקובץ משתקפת בקריאה הבאה', () async {
      final file = await writeDocx('נערך.docx', 'הגרסה הראשונה');
      expect(
        await readFileBackedBookText(file, 'docx', 'נערך'),
        contains('הגרסה הראשונה'),
      );

      await file.writeAsBytes(buildDocxBytes('הגרסה השנייה'));

      final updated = await readFileBackedBookText(file, 'docx', 'נערך');
      expect(updated, contains('הגרסה השנייה'));
      expect(updated, isNot(contains('הגרסה הראשונה')));
    });
  });

  group('טקסט', () {
    test('UTF-8 נקרא כרגיל', () async {
      final file = File(p.join(tempDir.path, 'רגיל.txt'));
      await file.writeAsString('שלום עולם');

      expect(await readFileBackedBookText(file, 'txt', 'רגיל'), 'שלום עולם');
    });

    test('Windows-1255 מפוענח נכון', () async {
      // 'שלום' ב-Windows-1255 — קידוד שאינו UTF-8 תקין.
      final file = File(p.join(tempDir.path, 'ישן.txt'));
      await file.writeAsBytes(const [0xF9, 0xEC, 0xE5, 0xED]);

      expect(await readFileBackedBookText(file, 'txt', 'ישן'), 'שלום');
    });

    test('קובץ ריק מחזיר מחרוזת ריקה', () async {
      final file = File(p.join(tempDir.path, 'ריק.txt'));
      await file.writeAsString('');

      expect(await readFileBackedBookText(file, 'txt', 'ריק'), isEmpty);
    });

    test('קובץ טקסט שאינו קיים זורק — הקורא מחליט מה לעשות', () async {
      final missing = File(p.join(tempDir.path, 'חסר.txt'));

      await expectLater(
        readFileBackedBookText(missing, 'txt', 'חסר'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
