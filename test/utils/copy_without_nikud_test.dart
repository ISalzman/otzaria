import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/text/copy_utils.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' show HolyNameStyle;
import 'package:otzaria/utils/ui/context_menu_utils.dart';

/// issue #851 — "העתק בלי ניקוד": ניקוד וטעמים מוסרים מהעותק בלבד,
/// התצוגה לא משתנה. הליבה היא שכבת העדפות-ההעתקה הקיימת (זו שכבר
/// מטפלת בהחלפת שמות קודש), עם דגל removeNikud.
void main() {
  const vocalized = 'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים';
  const plain = 'בראשית ברא אלהים';

  group('CopyUtils.applyCopyPreferences — removeNikud', () {
    test('מסיר ניקוד וטעמים יחד', () {
      expect(
        CopyUtils.applyCopyPreferences(
          text: vocalized,
          replaceHolyNames: false,
          removeNikud: true,
        ),
        plain,
      );
    });

    test('ברירת המחדל כבויה — הטקסט לא נגעה בו (התנהגות קיימת)', () {
      expect(
        CopyUtils.applyCopyPreferences(
          text: vocalized,
          replaceHolyNames: false,
        ),
        vocalized,
      );
    });

    test('משתלב עם החלפת שמות קודש — ההסרה רצה קודם', () {
      // שם הוי"ה מנוקד: ההסרה חושפת את השם, וההחלפה (יקוק) פועלת עליו.
      final result = CopyUtils.applyCopyPreferences(
        text: 'יְהוָה',
        replaceHolyNames: true,
        removeNikud: true,
      );
      expect(result, 'יקוק');
    });

    test("שומר על סגנון החלפת שם הוי\"ה שנבחר", () {
      final result = CopyUtils.applyCopyPreferences(
        text: 'יְהוָה',
        replaceHolyNames: true,
        holyNameStyle: HolyNameStyle.hehApostrophe,
        removeNikud: true,
      );

      expect(result, "ה'");
    });
  });

  group('CopyUtils.applyCopyPreferencesForClipboard — removeNikud', () {
    test('plain ו-HTML מנוקים יחד, והתגיות נשמרות', () {
      final result = CopyUtils.applyCopyPreferencesForClipboard(
        plainText: vocalized,
        htmlText: '<b>בְּרֵאשִׁ֖ית</b> בָּרָ֣א אֱלֹהִ֑ים',
        replaceHolyNames: false,
        removeNikud: true,
      );
      expect(result.plainText, plain);
      expect(result.htmlText, contains('<b>בראשית</b>'));
      expect(result.htmlText, isNot(contains('ְ')));
    });

    test('בלי הדגל — התנהגות קיימת ללא שינוי', () {
      final result = CopyUtils.applyCopyPreferencesForClipboard(
        plainText: vocalized,
        htmlText: '<b>$vocalized</b>',
        replaceHolyNames: false,
      );
      expect(result.plainText, vocalized);
      expect(result.htmlText, '<b>$vocalized</b>');
    });

    test("שומר על סגנון ה' גם ב-HTML", () {
      final result = CopyUtils.applyCopyPreferencesForClipboard(
        plainText: 'יְהוָה',
        htmlText: '<b>יְהוָה</b>',
        replaceHolyNames: true,
        holyNameStyle: HolyNameStyle.hehApostrophe,
        removeNikud: true,
      );

      expect(result.plainText, "ה'");
      expect(result.htmlText, "<b>ה'</b>");
    });
  });

  group('showCopyWithoutNikud — שער ההצגה בתפריט', () {
    test('מוצג רק כשהבחירה מכילה ניקוד או טעמים', () {
      expect(showCopyWithoutNikud(vocalized), isTrue);
      expect(showCopyWithoutNikud('וּלְקַחְתֶּם'), isTrue);
      // טעמים בלבד (בלי ניקוד) — עדיין רלוונטי להסרה.
      expect(showCopyWithoutNikud('ברא֖ אלהים'), isTrue);
    });

    test('טקסט לא מנוקד (גמרא), ריק או null — הפריט מוסתר', () {
      expect(showCopyWithoutNikud(plain), isFalse);
      expect(showCopyWithoutNikud('  '), isFalse);
      expect(showCopyWithoutNikud(null), isFalse);
    });
  });
}
