# תוצאות טסטים — העתקה מתוצאות חיפוש מכבדת את הגדרות "העתקה עם כותרת"

תאריך: 2026-08-19, ענף `fix/search-copy-with-headers` (בסיס dev `6c817f38`)
Flutter 3.44.0 / Dart 3.12.0, Windows 11

## מיפוי התקלה (קומיט הטסטים)

שלושה טסטי ווידג'ט חדשים ב-`test/search/tantivy_search_results_test.dart`
נכשלו על הקוד הקיים והוכיחו את התקלה: כפתור ההעתקה בכרטיס תוצאה העתיק את
הטקסט בלבד והתעלם מ-copyWithHeaders/copyHeaderFormat. טסט רביעי קיבע
שברירת המחדל (none) נשארת העתקת טקסט בלבד — עבר גם לפני התיקון.

## אחרי התיקון

- `flutter test test/search/tantivy_search_results_test.dart
  test/utils/text/copy_utils_test.dart` — **22 עברו, 0 נכשלו** (כולל שלושת
  טסטי התקלה וטסטי היחידה החדשים ל-`CopyUtils.referencePath`).
- `dart analyze` על הקבצים שנערכו — נקי.

## סוויטה מלאה

`flutter test` על כל המאגר: **8,172 עברו, 195 דולגו, 6 נכשלו.**

- ששת הכשלים קיימים-מראש וסביבתיים — אותם שישה בדיוק שאומתו מול baseline
  נקי (ללא שינויים) ביום הקודם: הרצת bash מ-test runner (release_packaging),
  סף כיווץ SQLite אחרי VACUUM (שלושה טסטי compaction), נעילת קובץ זמנית של
  Windows בניקוי טסט DOCX, ומפריד נתיב `\` מול `/` ב-custom_folder_model.
  אף אחד מהם אינו נוגע לאזור השינוי.
- 195 הדילוגים הם קבוצות התלויות ב-DLL של מנוע החיפוש, שריצתן דורשת בנייה
  מקומית. אחרי בניית Debug (שייצרה את ה-DLL) הורצו הקבוצות האלה בנפרד:
  `flutter test test/utils/ test/search/` — **1,101 עברו, 0 נכשלו**
  (כולל כל טסטי ההדגשה והניקוד של המנוע).

## בנייה

`flutter build windows --debug` — הצליחה; ה-EXE זמין לאימות ידני.
