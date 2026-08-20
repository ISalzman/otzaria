import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/text/copy_utils.dart';

void main() {
  group('CopyUtils.referencePath — גזירת נתיב מ-reference של תוצאת חיפוש', () {
    test('reference שאינו פותח בשם הספר מוחזר כמות שהוא', () {
      expect(
        CopyUtils.referencePath(bookName: 'ספר א', reference: 'סימן א'),
        'סימן א',
      );
    });

    test('reference שפותח בשם הספר ופסיק — הנתיב בלבד', () {
      expect(
        CopyUtils.referencePath(
          bookName: 'עבודה זרה',
          reference: 'עבודה זרה, דף עג.',
        ),
        'דף עג.',
      );
    });

    test('reference שפותח בשם הספר בלי פסיק — השארית בלבד', () {
      expect(
        CopyUtils.referencePath(
          bookName: 'בראשית',
          reference: 'בראשית פרק ד',
        ),
        'פרק ד',
      );
    });

    test('reference שמתחיל במילה עם קידומת שם הספר מוחזר כמות שהוא', () {
      expect(
        CopyUtils.referencePath(bookName: 'ספר', reference: 'ספרים, שער א'),
        'ספרים, שער א',
      );
    });

    test('reference שזהה לשם הספר — נתיב ריק (בלי הכפלה)', () {
      expect(
        CopyUtils.referencePath(bookName: 'ספר א', reference: 'ספר א'),
        '',
      );
    });

    test('שם ספר ריק — ה-reference מוחזר כמות שהוא', () {
      expect(
        CopyUtils.referencePath(bookName: '', reference: 'סימן א'),
        'סימן א',
      );
    });
  });

  group('CopyUtils.formatTextWithHeaders — שילוב עם הנתיב שנגזר', () {
    test('book_and_path עם נתיב ריק נופל לשם הספר בלבד', () {
      expect(
        CopyUtils.formatTextWithHeaders(
          originalText: 'טקסט',
          copyWithHeaders: 'book_and_path',
          copyHeaderFormat: 'same_line_after_brackets',
          bookName: 'ספר א',
          currentPath: '',
        ),
        'טקסט (ספר א)',
      );
    });

    test('book_and_path עם נתיב מלא מרכיב "ספר, נתיב"', () {
      expect(
        CopyUtils.formatTextWithHeaders(
          originalText: 'טקסט',
          copyWithHeaders: 'book_and_path',
          copyHeaderFormat: 'separate_line_before',
          bookName: 'עבודה זרה',
          currentPath: 'דף עג.',
        ),
        'עבודה זרה, דף עג.\nטקסט',
      );
    });
  });
}
