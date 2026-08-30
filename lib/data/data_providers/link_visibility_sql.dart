/// שברי ה-SQL של נראות-קישורים פר-צד (סכמה 3, טבלת `link_suppressed_side`).
///
/// מופרדים מ-`database_library_provider.dart` כדי שיהיו ניתנים לבדיקה: שם הם
/// מוזרקים לתוך שאילתות שרצות ב-isolate מול DB בן ג'יגה-בייטים.
///
/// מוסכמת הצדדים זהה ל-`link_anchor`/`link_range`: ‏0 = צד המקור השמור,
/// ‏1 = צד היעד. השאילתה הקדמית מציגה את צד 0, ההפוכה את צד 1.
///
/// שים לב: אין כאן parity מלא לספריא בקישורי הפניה — הפניה שאינה מדוכאת
/// ממשיכה להופיע רק מצד המקור השמור. המטרה מצומצמת: להעביר קישור שדוכא.
library;

/// מסנן את הצד שספריא אינה מציגה. [displayedSide] הוא הצד שהשורה שלו מוצגת.
String suppressedSideFilter(
  bool hasSuppressedSide, {
  required int displayedSide,
}) => hasSuppressedSide
    ? 'AND NOT EXISTS (SELECT 1 FROM link_suppressed_side ss '
          'WHERE ss.linkId = l.id AND ss.side = $displayedSide)'
    : '';

/// קישור הפניה עולה בשאילתה ההפוכה רק אם צדו השני הוסתר — זו כל מטרת
/// הדו-כיווניות: להעביר קישור שדוכא לצד המצטט, לא להוסיף "מי מצטט אותי".
/// בלי הצמצום כל הפניה גלויה הייתה מופיעה גם קדימה וגם הפוך, ומנפחת ספר בסיס
/// בעשרות אלפי שורות. תלויי-טקסט אינם מוגבלים — הם תמיד עלו הפוך.
String inverseScopeFilter(bool bidirectional, List<String> dependentTypes) {
  if (!bidirectional) return '';
  final quoted = dependentTypes.map((t) => "'$t'").join(', ');
  return 'AND (ct.name IN ($quoted) OR EXISTS (SELECT 1 FROM link_suppressed_side s0 '
      'WHERE s0.linkId = l.id AND s0.side = 0))';
}

/// בשאילתה ההפוכה קישור תלוי-טקסט מוצג כ-SOURCE הווירטואלי ("מה זה מפרש"),
/// אבל הפניה צדדית שעולה מהצד השני היא עדיין אותה הפניה — לא מקור. שימור
/// הסוג האמיתי משאיר אותה בפאנל הקישורים במקום להזריק אותה לפאנל המפרשים.
String inverseConnectionTypeExpr(List<String> dependentTypes) {
  final quoted = dependentTypes.map((t) => "'$t'").join(', ');
  return "CASE WHEN ct.name IN ($quoted) THEN 'SOURCE' ELSE ct.name END";
}
