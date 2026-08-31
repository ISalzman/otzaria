/// מפתח הפניה קנוני לרמת שורה — המקור היחיד לנרמול, משותף לבונה ה-DB
/// (`line_ref`), ל-FindRef, לתוספים ולבדיקות.
///
/// כל סטייה בין המימוש כאן למימוש ב-SeforimLibrary מייצרת החטאה שקטה
/// (hash שונה → אין מועמד), ולכן שני הצדדים נבדקים מול
/// `test/fixtures/ref_key_fixtures.json`.
library;

import 'dart:convert';

import 'package:otzaria/utils/text/text_manipulation.dart';

/// מילות מיקום שאינן חלק מערכי ההפניה ("פרק לג פסוק ה" ↔ "לג ה").
const Set<String> _locatorWords = {
  'פרק',
  'פסוק',
  'פסקה',
  'סעיף',
  'סימן',
  'הלכה',
  'משנה',
  'מאמר',
  'דף',
  'עמוד',
  'אות',
};

/// מרחיב סימון עמוד גמרא לטוקן עמוד מפורש: "ב." → "ב א", "ב:" → "ב ב".
///
/// בניגוד לנרמול הכללי הדפוס תופס גם סימן שאחריו פסיק ("ברכות ב., א") —
/// תבנית ה-heRef ב-DB, שבלעדיה מידע העמוד אובד.
String _expandDafMarks(String s) => s
    .replaceAllMapped(
      RegExp(r'''(?<![א-ת'"״׳])([א-ת]{1,3})\.(?=[,\s]|$)'''),
      (m) => '${m[1]} א',
    )
    .replaceAllMapped(
      RegExp(r'''(?<![א-ת'"״׳])([א-ת]{1,3}):(?=[,\s]|$)'''),
      (m) => '${m[1]} ב',
    );

/// טוקני המפתח הקנוני של [ref], לפי הסדר: חיתוך טווח, הרחבת סימוני דף,
/// הסרת ניקוד/טעמים/גרשיים/פיסוק, הסרת מילות מיקום ומיפוי ע"א/ע"ב.
List<String> refKeyTokens(String ref) {
  // חיתוך הטווח לפני הנרמול — המקף נהפך לרווח בהסרת הניקוד.
  final dash = ref.indexOf(RegExp('[-–־]'));
  final head = dash > 0 ? ref.substring(0, dash) : ref;

  var cleaned = removeTeamim(removeVolwels(_expandDafMarks(head)));
  cleaned = cleaned
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('״', '')
      .replaceAll('׳', '');
  cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9֐-׿\s]'), ' ').toLowerCase();

  return cleaned
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !_locatorWords.contains(t))
      .map((t) => t == 'עא' ? 'א' : (t == 'עב' ? 'ב' : t))
      .toList();
}

/// המפתח הקנוני של [ref], או `null` כשלא נותר ממנו דבר.
String? buildRefKey(String ref) {
  final tokens = refKeyTokens(ref);
  return tokens.isEmpty ? null : tokens.join(' ');
}

/// המפתח הקנוני של שורה: [heRef] לאחר קיצוץ הקידומת שהיא כותרת הספר.
///
/// [titleAliases] הן צורות הכותרת המוכרות; כשאף אחת אינה קידומת של ה-heRef
/// נשמר ה-heRef המלא, וזה מדווח כאי-התאמה בזמן הבנייה.
String? buildLineRefKey(String heRef, Iterable<String> titleAliases) {
  final tokens = refKeyTokens(heRef);
  if (tokens.isEmpty) return null;

  for (final alias in titleAliases) {
    final aliasTokens = refKeyTokens(alias);
    if (aliasTokens.isEmpty || aliasTokens.length > tokens.length) continue;
    var matches = true;
    for (var i = 0; i < aliasTokens.length; i++) {
      if (tokens[i] != aliasTokens[i]) {
        matches = false;
        break;
      }
    }
    if (!matches) continue;
    // שורת כותרת — ה-heRef הוא שם הספר בלבד ואין בה הפניה תת-רמתית.
    if (aliasTokens.length == tokens.length) return null;
    return tokens.sublist(aliasTokens.length).join(' ');
  }
  return tokens.join(' ');
}

/// FNV-1a 64 ביט על ייצוג ה-UTF-8 של [refKey], כערך חתום — הצורה שנשמרת
/// ב-`line_ref.refKeyHash` ומחושבת זהה בבונה ה-DB.
int refKeyHash(String refKey) {
  // חשבון 64 ביט עם גלישה — זהה ל-Long בבונה ה-DB.
  var hash = -3750763034362895579; // 14695981039346656037 כערך חתום
  for (final byte in utf8.encode(refKey)) {
    hash = (hash ^ byte) * 1099511628211;
  }
  return hash;
}
