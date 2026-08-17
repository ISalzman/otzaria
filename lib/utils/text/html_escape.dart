/// Escape של תווי HTML בתוכן *טקסט* (לא בתגיות שהממיר מייצר).
///
/// בלעדיו תוכן שמכיל `<`/`>`/`&` (נוסחאות, סוגריים מחודדים, "ר' & ...")
/// שובר את הרינדור: `HtmlWidget` מפרש `<` כתחילת תגית ומבלגן את המשך הפסקה.
String escapeHtmlText(String s) {
  if (!s.contains('&') && !s.contains('<') && !s.contains('>')) return s;
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Escape של ערך שהממיר משתיל בתוך `attr="…"`.
///
/// חייב לכסות גם גרשיים: ערך שמגיע מהמסמך (`xlink:href`, `fo:color`) ומכיל
/// `"` סוגר את המאפיין ומאפשר למסמך להזריק מאפיינים ותגיות משלו.
String escapeHtmlAttribute(String s) =>
    escapeHtmlText(s).replaceAll('"', '&quot;').replaceAll("'", '&#39;');
