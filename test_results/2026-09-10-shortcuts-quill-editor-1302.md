# issue #1302 — קיצור של אות בודדת נורה בזמן הקלדה בהערות אישיות

תאריך: 2026-09-10 | ענף: `fix/shortcuts-quill-editor-1302` | בסיס: `upstream/dev` (8c365b5cd) | קומיט אימות: `2536f1898`

## הבאג שאומת

`KeyboardShortcuts._isEditing` זיהה "שדה טקסט בפוקוס" רק לפי `EditableText` — הבסיס של
`TextField`/`RtlTextField`. עורך ההערות האישיות הוא `QuillEditor` של flutter_quill, שמטפל
בקלט בעצמו (`QuillRawEditorState` מממש `TextInputClient` ולא יורש מ-`EditableText`), ולכן
קיצור של אות בודדת ("פ" לחלונית המפרשים) נורה בזמן ההקלדה בו — בדיוק כפי שדווח, בעוד שבשאר
תיבות ההקלדה זה תוקן.

## הפתרון

הזיהוי הוחלף לקריטריון הכללי: ה-State של ה-widget בפוקוס (או של אב שלו) מממש
`TextInputClient` — נכון ל-`EditableTextState` וגם לעורך Quill, בלי תלות של מודול הקיצורים
בחבילת העורך.

## בדיקות

| קובץ | מה נבדק |
|---|---|
| `test/shortcuts/keyboard_shortcuts_test.dart` | חדש: קיצור `p` לחלונית המפרשים — בלי שדה טקסט מגלגל את החלונית; ב-`QuillEditor` בפוקוס נשאר הקלדה (נכשל על הבסיס: 1 במקום 0) |

`test/shortcuts/keyboard_shortcuts_test.dart`: **28 עברו**.

## אימות ויזואלי

קיצור החלונית הוגדר ל-`p` בהגדרות; בראשית, הערה חדשה מהתפריט, הקלדת `abc` ואז `p`.
בניית debug של הבסיס (dev 8c365b5cd) מול הענף. לפני: ה-`p` סגר את חלונית ההערות
(הקיצור נורה) ולא הוקלד; אחרי: `p` מוקלד בעורך והחלונית נשארת. הצילומים בענף
`pr-screenshots` (תיקייה `1302`).

## סוויטה מלאה

`flutter test` על הענף (במקביל לסוויטה נוספת ולאמולטור): **12,622 עברו, 23 דולגו, 11 נכשלו**.
עשרה כשלי בסיס מוכרים (release_packaging, compaction ×3, tab_context_menu,
personal_notes_file_backed_book, search_scope_menu, change_location_dialog, shamor_zachor,
database_library_provider "buildLibraryCatalog" — נכשל זהה על dev נקי). אחד רגיש-עומס שעבר
בבידוד: `core/windowing/single_window_regression_test`.
