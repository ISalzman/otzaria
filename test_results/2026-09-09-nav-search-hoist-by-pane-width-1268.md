# issue #1268 — שורת החיפוש נעלמת בתצוגה מפוצלת

תאריך: 2026-09-09 | ענף: `fix/nav-search-hoist-by-pane-width-1268` | בסיס: `upstream/dev` (1491afd5a) | קומיט אימות: `56cb42939`

## הבאג שאומת

`NavPanelSearch.canHoist` בדק את רוחב **החלון** (`MediaQuery` ≥ 600) כדי להחליט אם שדה
החיפוש של חלונית הניווט עולה לסרגל העליון. בתצוגה מפוצלת החלון רחב והחלונית צרה: השדה הורם
לסרגל בלי מקום, התכווץ לאייקון ליד כפתור ההגדרות, והחלונית לא ציירה שדה מקומי — הצילום שדווח.
שוחזר: בראשית לצד רש"י על בראשית, חלון 1100 (חלונית ~480).

## הפתרון

`SplitPaneView.buildPane` (עוטף כל חלונית, יחידה או מפוצלת) מספק `NavPanelPaneWidthScope`
מ-`LayoutBuilder`; `canHoist` קורא את רוחב החלונית ונופל ל-`MediaQuery` רק מחוץ לחלונית.
כפתור הנעיצה בסרגל משתמש באותה החלטה במקום בבדיקת `MediaQuery` נפרדת.

## בדיקות

| קובץ | מה נבדק |
|---|---|
| `test/widgets/nav_panel_search_test.dart` | חדש: חלונית 300 בחלון 1200 → `canHoist` false; כל חלונית ב-`SplitPaneView` מקבלת את רוחבה (נכשלו על הבסיס — ה-scope לא היה קיים) |

`nav_panel_search_test` + `split_pane_view_test` + `tab_strip_split_integration_test`: **58 עברו**.

## אימות ויזואלי

בניית debug של הבסיס ושל הענף, פיצול בראשית | רש"י, חלון 1100, חלונית הניווט פתוחה. לפני:
אייקון חיפוש דחוס ליד ההגדרות ובלי שדה בחלונית; אחרי: שדה "איתור כותרת..." מלא בתוך החלונית.
פס ה-overflow בקצה החלונית מופיע בשתי הבניות (בעיה נפרדת בבסיס). הצילומים בענף `pr-screenshots`
(תיקייה `1268`).

## סוויטה מלאה

`flutter test` על הענף (במקביל לסוויטה נוספת): **12,456 עברו, 9 דולגו, 12 נכשלו**. שמונה כשלי
בסיס מוכרים (release_packaging, compaction ×3, personal_notes_file_backed_book, search_scope_menu,
change_location_dialog, shamor_zachor). `text_book_bloc_test` ×3 — עברו בבידוד (רגישים לעומס).
`database_library_provider_test` "buildLibraryCatalog שומר מחבר" — נכשל באותה צורה גם על
`upstream/dev` נקי במכונה שקטה (מחיקת תיקיית temp אחרי `database is locked`) — כשל בסיס סביבתי.
