import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/utils/text/html_slice.dart';

void main() {
  group('sliceHtmlBySelection', () {
    test('בחירה שכולה בתוך תגית מחזירה את התגית סביבה', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>בראשית</b> ברא אלהים',
          selectedText: 'ראשית',
        ),
        '<b>ראשית</b>',
      );
    });

    test('בחירה שחוצה גבול תגית שומרת על שני החלקים', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>שלום</b> עולם',
          selectedText: 'לום עו',
        ),
        '<b>לום</b> עו',
      );
    });

    test('בחירה שכולה מחוץ לתגית מוחזרת ללא תגיות', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>שלום</b> עולם',
          selectedText: 'עולם',
        ),
        'עולם',
      );
    });

    test('בחירה מלאה מחזירה את כל המבנה', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>שלום</b> עולם',
          selectedText: 'שלום עולם',
        ),
        '<b>שלום</b> עולם',
      );
    });

    test('תגיות מקוננות נשמרות עם היררכיה מלאה', () {
      expect(
        sliceHtmlBySelection(
          html: '<h2><b>כותרת</b> משנה</h2>',
          selectedText: 'תרת מש',
        ),
        '<h2><b>תרת</b> מש</h2>',
      );
    });

    test('מאפייני התגית נשמרים בחיתוך', () {
      expect(
        sliceHtmlBySelection(
          html: '<span class="highlight" dir="rtl">טקסט ארוך</span>',
          selectedText: 'ארוך',
        ),
        '<span class="highlight" dir="rtl">ארוך</span>',
      );
    });

    test('<br> בתוך הבחירה נשמר כמעבר שורה', () {
      expect(
        sliceHtmlBySelection(
          html: 'שורה א<br>שורה ב',
          selectedText: 'רה א\nשור',
        ),
        'רה א<br>שור',
      );
    });

    test('<br> מחוץ לבחירה מושמט', () {
      expect(
        sliceHtmlBySelection(
          html: 'שורה א<br>שורה ב',
          selectedText: 'שורה ב',
        ),
        'שורה ב',
      );
    });

    test('בחירה מטקסט שמוצג ללא ניקוד נחתכת מהמקור המנוקד', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>בְּרֵאשִׁית</b> בָּרָא',
          selectedText: 'ראשית ב',
        ),
        '<b>ראשית</b> ב',
      );
    });

    test('הפרשי רווחים בין הבחירה למקור אינם מונעים התאמה', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>שלום</b>   עולם',
          selectedText: 'שלום עולם',
        ),
        '<b>שלום</b> עולם',
      );
    });

    test('ישויות HTML מקודדות מחדש בפלט', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>א&amp;ב</b> ג',
          selectedText: 'א&ב',
        ),
        '<b>א&amp;ב</b>',
      );
    });

    test('תגית ריקה שאינה בטווח הבחירה מושמטת', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>אלף</b><i>בית</i>',
          selectedText: 'בית',
        ),
        '<i>בית</i>',
      );
    });

    test('טקסט שחוזר בשורה עם עיצוב שונה מוותר על החיתוך', () {
      expect(
        sliceHtmlBySelection(
          html: '<big>אמר</big> רבא אמר רב',
          selectedText: 'אמר',
        ),
        isNull,
      );
    });

    test('טקסט שחוזר בשורה עם אותו עיצוב נחתך כרגיל', () {
      expect(
        sliceHtmlBySelection(
          html: 'אמר רבא אמר רב',
          selectedText: 'אמר',
        ),
        'אמר',
      );
    });

    test('גוף הערת שוליים מדולג — אינו מוצג ולכן אין להתאים אליו', () {
      expect(
        sliceHtmlBySelection(
          html: 'ויאמר <i class="footnote">אל משה</i> ואחר כך אל משה',
          selectedText: 'אל משה',
        ),
        'אל משה',
      );
    });

    test('מקף מקראי מותאם לרווח שמוצג במקומו', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>יְהִי־א֑וֹר</b> וַיְהִי',
          selectedText: 'יהי אור',
        ),
        '<b>יהי אור</b>',
      );
    });

    test('בחירה עם החלפת שם הוי"ה מותאמת למקור', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>ויאמר</b> יהוה אל משה',
          selectedText: 'ויאמר יקוק',
        ),
        '<b>ויאמר</b> יקוק',
      );
    });

    test('בחירה מטקסט שמוצג ללא פיסוק מותאמת למקור', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>אמר רבא:</b> מאי טעמא?',
          selectedText: 'אמר רבא מאי',
        ),
        '<b>אמר רבא</b> מאי',
      );
    });

    test('סימן פיסוק בתחילת הבחירה אינו נבלע', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>"שלום"</b> עולם',
          selectedText: '"שלום"',
        ),
        '<b>"שלום"</b>',
      );
    });

    test('רווח מוביל בבחירה נשמר', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>שלום</b> עולם',
          selectedText: ' עולם',
        ),
        ' עולם',
      );
    });

    test('ניקוד בתחילת הבחירה אינו נבלע', () {
      expect(
        sliceHtmlBySelection(
          html: 'וַ<b>יֹּאמֶר</b> משה',
          selectedText: 'ֹּאמֶר משה',
        ),
        '<b>ֹּאמֶר</b> משה',
      );
    });

    test('בחירה שחוזרת מעל התקרה מוותרת על החיתוך', () {
      final many = List.filled(13, 'אב').join(' ');
      expect(sliceHtmlBySelection(html: many, selectedText: 'אב'), isNull);

      final few = List.filled(12, 'אב').join(' ');
      expect(sliceHtmlBySelection(html: few, selectedText: 'אב'), 'אב');
    });

    test('מחזיר null כשהבחירה אינה נמצאת בשורה', () {
      expect(
        sliceHtmlBySelection(
          html: '<b>שלום</b> עולם',
          selectedText: 'טקסט אחר',
        ),
        isNull,
      );
    });

    test('מחזיר null לבחירה ריקה או לתוכן ריק', () {
      expect(
        sliceHtmlBySelection(html: '<b>שלום</b>', selectedText: '   '),
        isNull,
      );
      expect(sliceHtmlBySelection(html: '', selectedText: 'שלום'), isNull);
    });

    test('מחזיר null כשאין טקסט בתוכן', () {
      expect(
        sliceHtmlBySelection(html: '<br><br>', selectedText: 'שלום'),
        isNull,
      );
    });
  });
}
