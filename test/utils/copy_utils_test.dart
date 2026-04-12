import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/copy_utils.dart';

void main() {
  group('CopyUtils.applyCopyPreferences', () {
    test('מחליף שם הוי"ה כשההגדרה פעילה', () {
      final result = CopyUtils.applyCopyPreferences(
        text: 'ברוך אתה ה׳ ויהוה',
        replaceHolyNames: true,
      );

      expect(result, contains('יקוק'));
      expect(result, isNot(contains('יהוה')));
    });

    test('משאיר טקסט ללא שינוי כשההגדרה כבויה', () {
      final result = CopyUtils.applyCopyPreferences(
        text: 'יהוה',
        replaceHolyNames: false,
      );

      expect(result, 'יהוה');
    });
  });

  group('CopyUtils.applyCopyPreferencesForClipboard', () {
    test('שומר תגיות HTML כאשר שם הוי"ה נמצא בתוך text node יחיד', () {
      final result = CopyUtils.applyCopyPreferencesForClipboard(
        plainText: 'יהוה',
        htmlText: '<b>יהוה</b>',
        replaceHolyNames: true,
      );

      expect(result.plainText, 'יקוק');
      expect(result.htmlText, '<b>יקוק</b>');
    });

    test('נופל ל-plain text כאשר HTML מפצל את שם הוי"ה בין תגיות', () {
      final result = CopyUtils.applyCopyPreferencesForClipboard(
        plainText: 'יהוה',
        htmlText: 'י<b>הו</b>ה',
        replaceHolyNames: true,
      );

      expect(result.plainText, 'יקוק');
      expect(result.htmlText, 'יקוק');
    });
  });

  group('CopyUtils.buildStyledHtml', () {
    test('מייצר בלוקים נפרדים לכל שורה בלי תגיות br', () {
      final html = CopyUtils.buildStyledHtml(
        htmlText: 'שורה א\nשורה ב',
        fontFamily: 'David',
        fontSize: 20,
      );

      expect(html, contains('שורה א<br>שורה ב'));
      expect(html, contains('font-family: David;'));
    });

    test('שומר שורה ריקה כבלוק נפרד', () {
      final html = CopyUtils.buildStyledHtml(
        htmlText: 'שורה א\n\nשורה ב',
        fontFamily: 'David',
        fontSize: 20,
      );

      expect(html, contains('שורה א<br><br>שורה ב'));
    });
  });
}
