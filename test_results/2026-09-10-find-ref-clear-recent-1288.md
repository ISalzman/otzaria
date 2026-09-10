# issue #1288 — ניקוי "האיתורים האחרונים" בדיאלוג איתור המקורות

תאריך: 2026-09-10 | ענף: `fix/find-ref-clear-recent-1288` | בסיס: `upstream/dev` (8c365b5cd) | קומיט אימות: `d98d9f897`

## הבקשה שאומתה

`FindRefRecentStore` שומר עד 12 שאילתות שהובילו לפתיחת מקור ומציג אותן כצ'יפים במצב הפתיחה
של הדיאלוג. לא הייתה שום דרך למחוק אותן מהמסך — לא בודדות ולא כולן.

## המימוש

- כפתור ניקוי ליד התווית "האיתורים האחרונים" (tooltip "נקה" — מפתח קיים בקטלוג) —
  `FindRefRecentStore.clear()` והחזרת הדוגמאות.
- צ'יפ של איתור אחרון הוא `InputChip` עם כפתור הסרה ("הסר") — `FindRefRecentStore.forget(query)`;
  הסרת האחרון מחזירה את הדוגמאות. הדוגמאות נשארו `ActionChip` בלי הסרה.
- `_suggestions`/`_suggestionsAreRecent` הפכו משדות `late final` לשדות רגילים כדי שיתעדכנו.

## בדיקות

| קובץ | מה נבדק |
|---|---|
| `test/find_ref/find_ref_dialog_view_test.dart` | חדש: ניקוי מהמסך מוחק את הרשומות ומחזיר "דוגמאות" (נכשל על הבסיס — לא היה כפתור); הסרת איתור בודד משאירה את השאר, והסרת האחרון מחזירה דוגמאות. `_chipLabels` קורא את שני סוגי הצ'יפים |

`test/find_ref/` + `test/settings/l10n/`: **458 עברו**.

## אימות ויזואלי

בניית debug של הבסיס ושל הענף, `otzaria://open/detection` עם שני איתורים אחרונים. לפני: תווית
וצ'יפים בלי שום פעולת מחיקה; אחרי: X ליד התווית וכפתור הסרה על כל צ'יפ, ולחיצה על אחד מהם
מסירה רק אותו. הצילומים בענף
`pr-screenshots` (תיקייה `1288`).

## סוויטה מלאה

`flutter test` על הענף (במקביל לסוויטה נוספת ולאמולטור): **12,568 עברו, 23 דולגו, 15 נכשלו**.
עשרה כשלי בסיס מוכרים (release_packaging, compaction ×3, tab_context_menu,
personal_notes_file_backed_book, search_scope_menu, change_location_dialog, shamor_zachor,
database_library_provider "buildLibraryCatalog" — נכשל זהה על dev נקי). חמישה רגישי-עומס
שעברו בבידוד: `settings_bloc_test` "ניקוי פר-ספר", `text_book_bloc_test` ×4 (84 עברו יחד).
