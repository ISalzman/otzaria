/// חוזה ה-markup של טקסט אוצריא (§24) — **מקור יחיד**.
///
/// כל ממיר (Word, EPUB, ODT, RTF) מייצר את אותן תגיות בדיוק, ושכבת התצוגה,
/// תוכן העניינים והחיפוש מזהים אותן בלי לדעת מאיזה פורמט הגיעו. תבנית
/// שנכתבת פעמיים נוטה להיסתר בין הממירים, ואז אותו מסמך נראה אחרת לפי
/// הסיומת שלו.
library;

/// טקסט מסמך כשורת פלט אחת.
///
/// פלט אוצריא מופרד ב-`\n`, ולכן שורה-חדשה **בתוך** תוכן המסמך (מפיק שכותב
/// את ה-XML עם הזחה) הייתה מפצלת פסקה לכמה "שורות" ומסיטה את אינדקסי תוכן
/// העניינים ואת עוגני ההערות האישיות מול מה שהקורא רואה.
String otzariaInlineText(String text) =>
    text.contains('\n') || text.contains('\r')
    ? text.replaceAll(_lineBreaks, ' ')
    : text;

final RegExp _lineBreaks = RegExp(r'[\r\n]+');

/// תמונה מוטמעת. [src] ריק משאיר את התג במקומו — כך מבנה השורות, ועמו
/// מיקומי ההערות והסימניות, נשמר גם בהמרה חסרת-תמונות.
String otzariaImage(String src) => '<img src="$src" style="max-width: 100%;"/>';

/// סימן הערת שוליים. נכתב בנפרד מהגוף עבור ממיר שמרכיב אותם בשלבים.
///
/// [marker] הוא טקסט תצוגה ולא מספר: ב-EPUB הסימן נלקח מהעוגן שבמסמך
/// (`*`, `[1]`), ורק כשאין לו טקסט נופלים למונה רץ.
String otzariaFootnoteMarker(String marker) =>
    '<sup class="footnote-marker">$marker</sup>';

/// סימן הערת שוליים וגופה, צמודים — הצמידות היא מה ששכבת התצוגה מזהה.
String otzariaFootnote(String marker, String body) =>
    '${otzariaFootnoteMarker(marker)}<i class="footnote">$body</i>';

/// פתיחת טבלה. [attributes] מיועד ל-`dir="rtl"` בטבלה שהמסמך סימן כ-RTL.
String otzariaTableOpen({String attributes = ''}) =>
    '<table$attributes style="border-collapse: collapse; '
    'border: 1px solid #999;">';

/// סגנון תא בטבלה.
const String otzariaTableCellStyle = 'border: 1px solid #999; padding: 4px 8px';
