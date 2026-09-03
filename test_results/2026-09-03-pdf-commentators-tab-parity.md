# issue #1112 — כרטיסיית המפרשים שנפתחת מ-PDF: פערים מול כרטיסיית הטקסט

תאריך: 2026-09-03 | ענף: `fix/pdf-commentators-tab-parity-1112` | קומיט אימות: `1bcb5e23`

## מה אומת ומה לא

הדיווח כלל ארבע טענות. שתיים אומתו בקוד ותוקנו:

- **חלונית הצד לא נסגרת בגלילה כשאינה נעוצה** — `CommentatorsTabScreen`
  (טקסט) עוטף את רשימת המפרשים ב-`NotificationListener<UserScrollNotification>`
  שסוגר חלונית לא-נעוצה; ב-`PdfCommentatorsTabScreen` לא היה מקבילה.
- **המפרשים אינם מוגבלים לרוחב הטקסט** — כרטיסיית הטקסט מעבירה
  `contentMaxWidth` (מ-`textColumnMaxWidthOf` לפי הגדרת רוחב הטקסט) אל
  `CommentaryListBase`; ל-`PdfCommentaryPanel` לא היה פרמטר כזה כלל.

שתיים לא אומתו ולא שונו:

- "תוצאות בודדות של איתור כותרת מופיעות באמצע החלון" — רשימת הניווט בשתי
  הכרטיסיות בנויה מאותם רכיבים (`NavTreeFocusGroup` + `ScrollablePositionedList`
  עם `kNavTreeListPadding`) ולא נמצא מירכוז; לא שוחזר. אשמח לצילום.
- "אין אפשרות 'כל הדף' בתפריט" — ב-PDF לחיצה על גוף הכותרת בוחרת את כל
  הכותרת (כל המפרשים); שורת "כל הפרק" הנפרדת של כרטיסיית הטקסט חסרה כאן.
  זו הצעת אחידות ולא תקלה; לא טופלה בתיקון זה.

## הפתרון

- `PdfCommentatorsTabScreen`: `mainContent` עטוף ב-`NotificationListener<UserScrollNotification>`
  (`_closeNavPaneOnScroll`, אותו מנגנון של כרטיסיית הטקסט כולל דגל ה-microtask),
  ורוחב הרשימה מחושב ב-`LayoutBuilder` דרך `textColumnMaxWidthOf` ומועבר
  ל-`PdfCommentaryPanel.contentMaxWidth`.
- `PdfCommentaryPanel`: פרמטר `contentMaxWidth` ועטיפת הרשימה
  ב-`_constrainToContentWidth` (Align למעלה + ConstrainedBox) — זהה ל-`CommentaryListBase`,
  כך שפס הגלילה נשאר צמוד לדופן.

## בדיקות

`test/pdf_book/pdf_commentators_tab_screen_test.dart` — שתי בדיקות חדשות:
פתיחת חלונית הניווט ← `UserScrollNotification` מהרשימה ← החלונית נסגרת;
הגדרת רוחב טקסט 600 ← החלונית מקבלת `contentMaxWidth: 600`. שתיהן נכשלו
על `dev` (החלונית נשארה פתוחה; לא הועבר רוחב) ועוברות עם התיקון.

בדיקות ממוקדות `test/pdf_book/`: **481 עברו, 0 נכשלו**.

## אימות ויזואלי

המסך היה נעול (LogonUI) בזמן העבודה; ההוכחה היא בדיקות הווידג'ט על
המסך המלא של הכרטיסייה.

## סוויטה מלאה

`flutter test`: **11,608 עברו, 13 נכשלו, 9 דולגו** (76 דק' על מחשב נעול
ועמוס). הכשלים: הבסיס הסביבתי המוכר (release_packaging, ‏3×file_sync_compaction,
‏personal_notes_file_backed_book, ‏plugin_spec_freshness, ‏search_scope_menu flake,
‏change_location_dialog, ‏plugin_side_panel שאינו מתקמפל ב-`dev`) ועוד ארבעה
flakes-תחת-עומס שעוברים בהרצה מבודדת (`library_update_bloc_test`,
`index_freshness_warner_test`, `settings_bloc_test`, `text_book_bloc_test`).
אפס רגרסיות.
