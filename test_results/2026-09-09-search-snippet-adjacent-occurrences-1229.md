# issue #1229 — פיצול תוצאות חיפוש משורה אחת לקטעים קטומים

תאריך: 2026-09-09 | ענף: `fix/search-snippet-adjacent-occurrences-1229` | בסיס: `upstream/dev` (1491afd5a) | קומיט אימות: `15480901e`

## הבאג שאומת

בחיפוש בתוך ספר כל הופעה באותה שורה היא תוצאה נפרדת (216c41c5e), וה-snippet שלה נחתך
בחצי הדרך להופעה השכנה כדי להציג רק את ההופעה שלה. כשההופעות צמודות — עירובין לו:,
"קַשְׁיָא חָכָם אַחָכָם!" בחיפוש "חכם" בהתאמה חלקית — החצי משאיר שבר מילה, והתוצאות שהתקבלו
היו "אחכם!" ו"חכם" בלי הקשר, בדיוק כמו בצילום שדווח. שוחזר על שורה 1337 של הספר במסד.

## הפתרון

`_snippetAroundMatch` מפעיל את גבול חצי-הדרך רק כשהוא משאיר לפחות מילה שלמה ליד ההופעה
(`_hasNeighborWord`); אחרת אותו צד מקבל את ההקשר המלא (90 תווים בגבולות מילים) גם אם הוא
חופף לשכנה. העיצוב "תוצאה לכל הופעה, snippet שמציג רק אותה" נשמר לכל שאר המקרים, וההיסטים
לגלילה לא השתנו.

## בדיקות

| קובץ | מה נבדק |
|---|---|
| `test/text_book/utils/section_search_utils_test.dart` | חדש: שתי הופעות צמודות — שני ה-snippets מכילים את הביטוי השלם (נכשל על הבסיס: `'קשיא גוים אגוים, קשיא חכם'`) |
| קיימים | "הופעות קרובות — כל snippet מכיל רק את ההופעה שלו", "תוצאה לכל הופעה — שלמה וחלקית" ממשיכים לעבור |

`section_search_utils_test` + `section_search_worker_test` + `text_book_search_screen_test`: **85 עברו**.

## אימות ויזואלי

בניית debug של הבסיס ושל הענף, `otzaria://open/book/105?index=1337&q=חכם`, כיבוי "מילים
שלמות". לפני: 15 תוצאות ובהן "אחכם!" ו"חכם" כתוצאות בודדות; אחרי: 15 תוצאות, כל אחת עם
ההקשר המלא. הצילומים בענף `pr-screenshots` (תיקייה `1229`).

## סוויטה מלאה

`flutter test` על הענף (במקביל לסוויטה נוספת ב-worktree אחר): **12,453 עברו, 9 דולגו, 14 נכשלו**.
תשעה כשלי בסיס מוכרים (release_packaging, compaction ×3, tab_context_menu,
personal_notes_file_backed_book, search_scope_menu, change_location_dialog, shamor_zachor).
ארבעה נוספים עברו בבידוד — רגישים לעומס: `find_ref_db_isolate_shared_queries_test`,
`text_book_bloc_test` ×2, `raised_markers_perf_test`. האחרון —
`data_providers/database_library_provider_test` "buildLibraryCatalog שומר מחבר" — (יעודכן).
