# issue #1130 — הבזק "לא נמצאו מפרשים" בין "טוען מפרשים..." לתוצאות

תאריך: 2026-09-02 | ענף: `fix/commentary-panel-not-found-flash-1130` | קומיט אימות: `bc325ddc`

## שורש הבאג

בפתיחת ספר `_onLoadContent` מפעיל במקביל את טעינת הקישורים ואת טעינת
המפרשים. כשעדיין אין בחירת מפרשים (ספר שנפתח בלי כרטיסייה משוחזרת),
`_resolveTargetBookTitlesForLinks` מחזיר רשימת יעדים ריקה — הקישורים חוזרים
בלי מפרשים, `linksLoading` יורד ל-false, וחלונית המפרשים מסיקה "לא נמצאו
מפרשים לקטע הנבחר". רק אחר כך מגיעה בחירת ברירת-המחדל (`UpdateCommentators`)
שמפעילה טעינה חוזרת — "טוען" שוב ואז התוצאות. בדיוק ההקלטה שבדיווח.

רצף המצבים שנמדד ב-`dev` (בדיקת ה-BLoC, לפני התיקון):

```
loading=true  active=[]         links=0   ← "טוען מפרשים..."
loading=false active=[]         links=0   ← "לא נמצאו מפרשים"  (ההבזק)
loading=false active=[רש"י ...] links=0   ← עדיין "לא נמצאו"
loading=true  active=[רש"י ...] links=0   ← "טוען" שוב
loading=false active=[רש"י ...] links=N   ← התוצאות
```

## הפתרון

כשנדרשת טעינת מפרשים והבחירה עדיין ריקה, טעינת הקישורים נדחית עד שהבחירה
נפתרת: המצב ההתחלתי מסומן `linksLoading: true` (החלונית מציגה "טוען"),
והטעינה יוצאת מ-`UpdateCommentators` — או, במסלולים שבהם לא נשלחת בחירה
(אין מפרשים לספר, בחירה אוטומטית שנדחתה כי המשתמש כבר בחר, כשל בטעינת
המפרשים), מ-`_loadLinksAfterCommentatorsResolved`. כרטיסייה שנפתחת עם
מפרשים ידועים ממשיכה לטעון קישורים מיד כמו קודם.

## בדיקות

`test/text_book/bloc/commentary_links_no_not_found_flash_test.dart` — מריץ
`LoadContent` על BLoC אמיתי עם מאגר מזויף שבו רשימת המפרשים איטית מהקישורים
(כמו במציאות), ומוודא שמרגע "טוען" אין אף מצב שבו החלונית הייתה מציגה
"לא נמצאו" לפני התוצאות. נכשלת על `dev` ועוברת עם התיקון.

בדיקות ממוקדות: `test/text_book/`, `test/tabs/`, `test/plugins/bridge/` —
**2,354 עברו, 0 נכשלו**.

## אימות ויזואלי

ההבזק נמשך פריים אחד ואינו ניתן לצילום אמין; ההוכחה היא רצף המצבים
שנמדד מה-BLoC לפני התיקון (למעלה) ובדיקת הרגרסיה שמוודאת שהוא אינו חוזר.

## סוויטה מלאה

`flutter test`: **11,609 עברו, 11 נכשלו, 9 דולגו**. הכשלים: הבסיס הסביבתי
המוכר (release_packaging, ‏3×file_sync_compaction, ‏personal_notes_file_backed_book,
‏plugin_spec_freshness, ‏search_scope_menu flake, ‏change_location_dialog),
‏`plugin_side_panel_test` שאינו מתקמפל ב-`dev` מאז עדכון file_picker
(`_FakePlatformFile` חסר `lengthSync`), ושני flakes-תחת-עומס שעוברים בהרצה
מבודדת (`index_freshness_warner_test`, `raised_markers_perf_test`). אפס
רגרסיות.
