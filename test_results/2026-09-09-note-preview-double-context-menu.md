# issue #1271 — תפריט העתקה כפול בתיבת הריחוף של הערה אישית

תאריך: 2026-09-09 | ענף: `fix/note-preview-double-context-menu-1271` | קומיט אימות: `e70a7ac7f`

## הבאג שאומת

תיבת הריחוף של הערה על הטקסט (`LinkPreviewOverlay.showContent` ←
`PersonalNotesListView`) עטופה ב-`AppSelectionArea`, שמספק את תפריט "העתק" של
אוצריא. בתוכה `PersonalNoteContentView` מרנדר את ההערה ב-`QuillEditor` לקריאה
בלי `contextMenuBuilder`, ולכן לחיצה ימנית פתחה גם את
`AdaptiveTextSelectionToolbar` של Flutter — שני תפריטים זה לצד זה, כפי שדווח.
בשאר המסכים העורכים/אזורי הבחירה כבר משתיקים את תפריט Flutter
(`contextMenuBuilder: (_, _) => const SizedBox.shrink()`).

## הפתרון

`PersonalNoteContentView` משתיק את תפריט העורך רק כשיש `AppSelectionArea` מעליו
(שם ההעתקה מסופקת ממנו). בלי מארח כזה — דיאלוג "הערה מקושרת" בחלונית ההערות —
תפריט העורך הוא הדרך היחידה להעתיק, ולכן נשמר.

## בדיקות

`test/personal_notes/personal_note_content_view_context_menu_test.dart` (חדש):
לחיצה ימנית בתוך `AppSelectionArea` ← "העתק" יחיד ובלי `AdaptiveTextSelectionToolbar`
(נכשל על הבסיס: נמצא תפריט Flutter); בלי `AppSelectionArea` ← תפריט העורך נשאר.

בדיקות ממוקדות `test/personal_notes/` + `link_preview_overlay_test`: עברו, כשל
יחיד `personal_notes_file_backed_book_test` (הבסיס הסביבתי המוכר).

## הערה על הבסיס

הענף מבוסס על `d4503f480` (Merge #1220) ולא על ראש `dev`: ראש `dev` (511529810)
אינו מתקמפל — `lib/library_update/` משתמש ב-API של `seforim_library_updater`
שעדיין לא פורסם ל-`main` של החבילה (יושב ב-PR #11 שלה), וגם CI של `dev` אדום.

## סוויטה מלאה

`flutter test`: **12,337 עברו, 9 דולגו**. בריצה הראשונה נכשלו 91 בדיקות
בקבצי מנוע החיפוש ותוספים בגלל DLL של המנוע שנותר מבניית Release ולא תאם
את קוד ה-FRB (`frb_generated.rs: entered unreachable code`); אחרי בנייה
מחדש של הפלאגין כולם עברו בהרצה חוזרת (316 בדיקות), למעט
`shamor_zachor_data_provider_test` — שנכשל באותה צורה על הבסיס בכל שלושת
ה-worktrees, בלי קשר לשינוי. שאר הכשלים: הבסיס הסביבתי המוכר
(release_packaging, ‏3×file_sync_compaction, ‏personal_notes_file_backed_book,
‏search_scope_menu flake, ‏change_location_dialog). אפס רגרסיות.
