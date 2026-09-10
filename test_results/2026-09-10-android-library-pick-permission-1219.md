# issue #1219 — בחירת תיקיית ספרייה באנדרואיד נופלת ב"שגיאה 13"

תאריך: 2026-09-10 | ענף: `fix/android-library-pick-permission-1219` | בסיס: `upstream/dev` (8c365b5cd) | קומיט אימות: `e2e947f34`

## הבאג שאומת

שוחזר באמולטור Android 14 (API 34, google_apis x86_64) עם `seforim.db` ב-`/sdcard/Download/otzaria_lib`:
"בחירת תיקייה מהמחשב" → "בחר תיקייה" → הדיאלוג הציג שהקובץ זוהה ("חסרים: קטלוג, מילון, תלמוד"), האישור
הופעל, והייבוא נכשל ב-`PathAccessException ... (OS Error: Permission denied, errno = 13)`. ההודעה מוצגת
מתחת לקפל הדיאלוג. מסלול "בחר קובץ ספרייה" (SAF) עבד: הקובץ הועתק ל-`app_flutter/books/seforim.db`.

## המקור

תחת Scoped Storage, `File.exists()` מחזיר `true` לקובץ באחסון המשותף גם כשאין הרשאת קריאה
(`stat` מותר, `open` נחסם). `_scanFolderAssets` בדיאלוג הסתמך על `exists()` בלבד.
הרשאות האחסון ב-manifest מוגבלות ל-API 32; באנדרואיד 13+ אין דרך לקרוא קובץ כזה דרך נתיב.

## התיקון

- `scanLibraryFolderAssets` (במקום `_scanFolderAssets`): אחרי זיהוי הקבצים פותח את הראשון שנמצא לקריאה;
  `PathAccessException` מסמנת את התיקייה כלא-נגישה (`readable: false`, ללא נכסים). hook
  `debugLibraryFolderReadProbe` לבדיקות.
- `_sourceFolderUnreadable` בדיאלוג: כותרת משנה "לתוכנה אין הרשאת קריאה לתיקייה שנבחרה — יש לבחור את קובץ
  seforim.db דרך "בחר קובץ ספרייה"", האישור נשאר מושבת. בחירת קובץ מאפסת את הדגל.
- `EmptyLibraryBloc._onImportLibraryFolderRequested`: `PathAccessException` → הודעה מובנת עם אותה הנחיה.
- תרגום לאנגלית ב-`settings_en.arb`, הקטלוג נוצר מחדש.

## בדיקות

| קובץ | מה נבדק |
|---|---|
| `test/settings/dialogs/library_setup_dialog_test.dart` | חדש (קבוצה "issue #1219"): סריקה עם probe שזורק `PathAccessException` → לא נגיש וללא נכסים; סריקה רגילה → seforim.db זוהה; widget: בורר תיקייה מזויף + probe חוסם → ההנחיה מוצגת, "כל הקבצים זוהו" לא, אישור מושבת; תיקייה קריאה → אישור פעיל. על הבסיס הקבוצה נכשלת (הסריקה מדווחת "כל הקבצים זוהו"). |

`flutter test test/settings/dialogs/library_setup_dialog_test.dart`: **18 עברו**.
`flutter test test/settings/l10n/ test/empty_library/`: **193 עברו**. `flutter analyze` נקי, `dart format` ללא שינויים.

## אימות ויזואלי

APK debug של הבסיס ושל הענף על האמולטור (Flutter ברינדור תוכנה — ה-GPU של האמולטור מקריס את qemu במחשב
הבדיקה). לפני: "Still Missing: קטלוג…" ואחרי אישור errno 13; אחרי: ההנחיה ואישור מושבת (עברית ואנגלית).
הצילומים בענף `pr-screenshots` (תיקייה `1219`).

## סוויטה מלאה

`flutter test` על הענף (במקביל לאמולטור): **12,626 עברו, 23 דולגו, 9 נכשלו** — כולם כשלי הבסיס המוכרים:
release_packaging, compaction ×3, personal_notes_file_backed_book, search_scope_menu (flaky),
change_location_dialog, shamor_zachor, database_library_provider "buildLibraryCatalog".
