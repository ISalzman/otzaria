# issue #1055 — מונה התאמות החיפוש במפרשים סופר כמו שההדגשה צובעת

תאריך: 2026-08-31 | ענף: `feature/commentary-count-partial-1055` | קומיט קוד: `2c057902`

## שורש הבאג

באותו ווידג'ט חושבו שני מספרים במדיניות שונה: הרינדור מדגיש בהתאמה חלקית
(`RenderSettings.partialWordHighlight: true`) בעוד `countMatches` תמיד דרש
גבולות-מילה — הוא כלל לא קיבל `partialWordMatch`. "אמר" נצבע בתוך "ויאמר"
אך לא נספר, בניגוד מפורש להבטחת ה-doc ("המונה המוצג לעולם לא סוטה ממספר
ההדגשות בפועל").

## הפתרון

הדגל `partialWordMatch` מושחל דרך שלוש השכבות — `countMatches` →
`TextRendererService.countSearchMatches` → `countCommentarySearchMatches`
(שם הוא required, כך שכל משטח חייב להצהיר) — ושלושת משטחי המפרשים
(commentary_content, commentary_list_base, pdf_commentary_panel) מוסרים
`true`, אותו ערך שמגיע לרינדור. חישוב הגבולות זהה לזה של `highLight`.
ברירת המחדל של `countMatches` נשארה מילים-שלמות — אף התנהגות אחרת לא השתנתה.

## בדיקות

`test/text_book/utils/commentary_search_count_test.dart` — 3 בדיקות:
ברירת המחדל ללא שינוי; עם הדגל "ויאמר"/"ונאמר" נספרות; ו-
`countCommentarySearchMatches` מחזיר 2 מול 1 על אותו תוכן מנוקד לפי הדגל.
בנוסף עברו כל `test/text_book/`, `test/widgets/`, `test/pdf_book/`,
`test/utils/` — 4,250 בדיקות.

## אימות ויזואלי (רד"ק על ישעיהו ל, חיפוש "אמר")

אותו מסך בדיוק, אותן הדגשות (אמר, שאמר, נאמר, ואמר...):

| גרסה | המונה | צילום |
|---|---|---|
| לפני (בסיס) | **1/2** — סופר רק מילים שלמות | `img/1055-before-count2.jpg` |
| אחרי (הענף) | **1/9** — תואם את ההדגשות | `img/1055-after-count9.jpg` |

## סוויטה מלאה

`flutter test`: **11,105 עברו, 9 נכשלו** — 8 הכשלים הסביבתיים/קיימים-מראש
המוכרים + `raised_markers_perf` שנכשל תחת עומס מכונה ועובר בהרצה מבודדת
(אומת). אפס רגרסיות.
