# issue #1280 — טעינת הגדרת מיקום הטאבים מאוחרת

תאריך: 2026-09-09 | ענף: `fix/settings-initial-state-sync-1280` | בסיס: `upstream/dev` (1491afd5a) | קומיט אימות: `bb6ca8635`

## הבאג שאומת

`SettingsBloc` נוצר עם `SettingsState.initial()` — ברירות המחדל — ורק `LoadSettings`
האסינכרוני (כתיבת ברירות מחדל בהפעלה ראשונה, ניקוי קיצורים, ו-`AppFonts.ensureFontLoaded`
לגופני מערכת) מחליף אותו במצב השמור. עד שהוא מסתיים המסך נבנה עם `readingTabsPlacementTop`,
ואז הטאבים קופצים הצידה — בדיוק כפי שדווח. כל הקריאות מ-`Settings` הן סינכרוניות
(`Settings.init` רץ לפני `runApp`), ולכן אין סיבה שהמצב ההתחלתי יתעלם מהן.

## הפתרון

- `SettingsRepository.readSettings()` — תמונת ההגדרות השמורות, סינכרונית; `loadSettings()`
  משתמש בה אחרי האתחולים. `getShortcuts()` נשען על `readShortcuts()` הסינכרוני.
- `SettingsBloc` מקבל `initialSettings` ובונה ממנו את המצב ההתחלתי דרך `_stateFromSettings`
  — אותה פונקציה שמשמשת גם את `LoadSettings` (במקום בלוק ה-`emit` המשוכפל).
- `main.dart` מעביר `settingsRepository.readSettings()`.

## בדיקות

| קובץ | מה נבדק |
|---|---|
| `test/settings/settings_bloc_test.dart` | חדש: bloc שנבנה עם `initialSettings` מתחיל עם מיקום טאבים "בצד" בלי `LoadSettings` (נכשל על הבסיס — הפרמטר לא היה קיים); בלי הגדרות התחלתיות המצב הוא ברירת המחדל. `mockSettings` הועלה לקבוצה החיצונית לשימוש משותף |

בדיקות ממוקדות `test/settings` + `test/navigation`: עברו כולן פרט ל-`change_location_dialog_test` (כשל בסיס מוכר).

## אימות ויזואלי

בנייה `flutter build windows --debug` של הבסיס ושל הענף, מיקום טאבים "בצד" בהגדרות,
צילום רצף פריימים מרגע הופעת החלון (`open/inspection`). במחשב הזה החלון מופיע רק אחרי
שההגדרות כבר נטענו (גופנים מצורפים נטענים מיד), ולכן **ההבזק לא נראה באף אחת מהבניות** —
הפריים הראשון בשתיהן מציג את הטאבים בצד. הבאג מתועד בקוד (מצב התחלתי = ברירות מחדל) ומשוחזר
בבדיקת היחידה; ההבזק שדווח תלוי במשך `ensureFontLoaded`/האתחולים במכונת המדווח.

## סוויטה מלאה

`flutter test` על הענף: **12,458 עברו, 9 דולגו, 10 נכשלו**. תשעה הם כשלי הבסיס המוכרים
(release_packaging, compaction ×3, tab_context_menu, personal_notes_file_backed_book,
search_scope_menu, change_location_dialog, shamor_zachor). העשירי — `data_providers/database_library_provider_test` "buildLibraryCatalog שומר מחבר" — נכשל
באותה צורה גם על `upstream/dev` נקי במכונה שקטה (מחיקת תיקיית temp נכשלת: "used by another process"
אחרי `database is locked`) — כשל בסיס סביבתי, לא קשור לשינוי.
