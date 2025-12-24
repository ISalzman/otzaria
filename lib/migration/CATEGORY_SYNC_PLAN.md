# תכנון מימוש סנכרון קטגוריות וספרים

## סקירה כללית

מסמך זה מתאר את השלבים הנדרשים למימוש מנגנון סנכרון אוטומטי בין מערכת הקבצים למסד הנתונים.

---

## שלב 1: סריקת שינויים בתיקיית אוצריא

### מטרה
זיהוי קבצי TXT חדשים או משתנים תחת תיקיית אוצריא.

### משימות
- [x] 1.1 יצירת פונקציה `scanForChanges(String otzariaPath)` שסורקת את כל התיקיות
- [x] 1.2 השוואת רשימת הקבצים הקיימים מול הספרים ב-DB
- [x] 1.3 זיהוי קבצים חדשים (לא קיימים ב-DB)
- [ ] 1.4 זיהוי קבצים שהשתנו (לפי תאריך שינוי או hash)

### קלט/פלט
```dart
class FileChangeResult {
  final List<String> newFiles;      // קבצים חדשים להוספה
  final List<String> modifiedFiles; // קבצים שהשתנו לעדכון
  final List<String> deletedFiles;  // קבצים שנמחקו (אופציונלי)
}

Future<FileChangeResult> scanForChanges(String otzariaPath);
```

---

## שלב 2: פירוק נתיב לרכיבי קטגוריה

### מטרה
המרת נתיב קובץ לרשימת קטגוריות היררכית.

### משימות
- [x] 2.1 יצירת פונקציה `parsePathToCategories(String filePath, String basePath)`
- [x] 2.2 הסרת נתיב הבסיס והשארת ההיררכיה בלבד
- [x] 2.3 הפרדת שם הספר מהקטגוריות

### דוגמה
```dart
// קלט
basePath: "C:\אוצריא"
filePath: "C:\אוצריא\לימוד יומי\חוק לישראל\חק לישראל - בראשית.txt"

// פלט
categories: ["לימוד יומי", "חוק לישראל"]
bookName: "חק לישראל - בראשית"
```

---

## שלב 3: חיפוש/יצירת קטגוריה בהיררכיה

### מטרה
מציאת קטגוריה קיימת או יצירת חדשה לפי שרשרת ההיררכיה.

### משימות
- [ ] 3.1 יצירת פונקציה `findCategoryByHierarchy(List<String> categoryPath)`
- [ ] 3.2 יצירת פונקציה `createCategoryChain(List<String> categoryPath)`
- [ ] 3.3 יצירת פונקציה משולבת `findOrCreateCategory(List<String> categoryPath)`
- [ ] 3.4 מימוש שליפת MAX(id) ויצירת מזהה חדש

### לוגיקה
```dart
Future<int> findOrCreateCategory(List<String> categoryPath) async {
  int? parentId = null;
  
  for (final categoryName in categoryPath) {
    // חיפוש קטגוריה עם שם זה תחת האב הנוכחי
    final category = await findCategory(categoryName, parentId);
    
    if (category != null) {
      parentId = category.id;
    } else {
      // יצירת קטגוריה חדשה
      parentId = await createCategory(categoryName, parentId);
    }
  }
  
  return parentId!;
}
```

---

## שלב 4: בדיקת קיום ספר בקטגוריה

### מטרה
קביעה האם הספר קיים ונדרש עדכון, או שזהו ספר חדש.

**עדכון חשוב**: הבדיקה משתנה מבדיקה לפי שם בלבד לבדיקה לפי שם **וקטגוריה**. 
זה אומר שספר עם אותו שם יכול להיות בקטגוריות שונות ולא להיחשב כפול.

### משימות
- [x] 4.1 יצירת פונקציה `findBookInCategory(String bookName, int categoryId)`
- [x] 4.2 החזרת מזהה הספר אם קיים, או null אם לא
- [x] 4.3 עדכון הלוגיקה במערכת לבדיקה לפי שם וקטגוריה

### שאילתה מעודכנת
```sql
SELECT id FROM book 
WHERE title = ? AND categoryId = ?
```

---

## שלב 5: עדכון ספר קיים

### מטרה
עדכון תוכן ספר קיים (שורות וכותרות).

### משימות
- [ ] 5.1 יצירת פונקציה `updateBookContent(int bookId, String filePath)`
- [ ] 5.2 מחיקת שורות קיימות של הספר
- [ ] 5.3 מחיקת ערכי TOC קיימים
- [ ] 5.4 קריאת הקובץ החדש ופירוסו
- [ ] 5.5 הכנסת שורות חדשות
- [ ] 5.6 הכנסת ערכי TOC חדשים
- [ ] 5.7 עדכון timestamp של הספר

### Transaction
```dart
await db.transaction((txn) async {
  await txn.delete('line', where: 'bookId = ?', whereArgs: [bookId]);
  await txn.delete('tocEntry', where: 'bookId = ?', whereArgs: [bookId]);
  
  // הכנסת נתונים חדשים
  await insertLines(txn, bookId, lines);
  await insertTocEntries(txn, bookId, tocEntries);
  
  await txn.update('book', {'updatedAt': DateTime.now()}, 
    where: 'id = ?', whereArgs: [bookId]);
});
```

---

## שלב 6: הוספת ספר חדש

### מטרה
הוספת ספר חדש לחלוטין למסד הנתונים.

### משימות
- [ ] 6.1 יצירת פונקציה `addNewBook(String filePath, int categoryId)`
- [ ] 6.2 קריאת הקובץ ופירוסו
- [ ] 6.3 יצירת רשומת ספר חדשה
- [ ] 6.4 הכנסת שורות
- [ ] 6.5 הכנסת ערכי TOC
- [ ] 6.6 עדכון category_closure אם נדרש

---

## שלב 7: ניקוי קבצים לאחר עיבוד

### מטרה
מחיקת קבצי TXT שעובדו ותיקיות ריקות.

### משימות
- [ ] 7.1 יצירת פונקציה `cleanupProcessedFiles(List<String> processedFiles)`
- [ ] 7.2 מחיקת קבצי TXT שעובדו בהצלחה
- [ ] 7.3 סריקה ומחיקת תיקיות ריקות (מלמטה למעלה)
- [ ] 7.4 אוצריא על קבצי PDF במקומם

### אלגוריתם מחיקת תיקיות ריקות
```dart
Future<void> removeEmptyDirectories(String basePath) async {
  final dir = Directory(basePath);
  final entities = await dir.list(recursive: true).toList();
  
  // מיון מהעמוק לרדוד
  entities.sort((a, b) => b.path.length.compareTo(a.path.length));
  
  for (final entity in entities) {
    if (entity is Directory) {
      final contents = await entity.list().toList();
      if (contents.isEmpty) {
        await entity.delete();
      }
    }
  }
}
```

---

## שלב 8: אינטגרציה - פונקציה ראשית

### מטרה
חיבור כל השלבים לפונקציה אחת מתואמת.

### משימות
- [ ] 8.1 יצירת פונקציה `syncFilesToDatabase(String otzariaPath)`
- [ ] 8.2 הוספת logging לכל שלב
- [ ] 8.3 טיפול בשגיאות והחזרת דוח סיכום
- [ ] 8.4 תמיכה ב-progress callback לעדכון UI

### ממשק
```dart
class SyncResult {
  final int addedBooks;
  final int updatedBooks;
  final int addedCategories;
  final int deletedFiles;
  final List<String> errors;
}

Future<SyncResult> syncFilesToDatabase(
  String otzariaPath, {
  void Function(double progress, String message)? onProgress,
});
```

---

## שלב 9: בדיקות

### משימות
- [ ] 9.1 בדיקת יצירת קטגוריה חדשה
- [ ] 9.2 בדיקת מציאת קטגוריה קיימת
- [ ] 9.3 בדיקת הוספת ספר חדש
- [ ] 9.4 בדיקת עדכון ספר קיים
- [ ] 9.5 בדיקת מחיקת קבצים ותיקיות ריקות
- [ ] 9.6 בדיקת אוצריא על קבצי PDF

---

## עדכון מימוש - בדיקת ספרים כפולים לפי קטגוריה

### שינויים שבוצעו:

1. **BookQueries.sq**: הוספת שאילתה `selectByTitleAndCategory` לבדיקת ספר לפי שם וקטגוריה
2. **BookDao**: הוספת פונקציה `getBookByTitleAndCategory(String title, int categoryId)`
3. **SeforimRepository**: 
   - הוספת פונקציה `getBookByTitleAndCategory(String title, int categoryId)`
   - הוספת פונקציה `checkBookExistsInCategory(String title, int categoryId)`
4. **DatabaseGenerator**: 
   - עדכון הcallback signature לקבל גם categoryId
   - שינוי הבדיקה מ-`checkBookExists` ל-`checkBookExistsInCategory`
5. **DatabaseGenerationScreen**: 
   - עדכון הcallback לקבל categoryId ולהציג שם קטגוריה בדיווח
   - עדכון הטקסט ההסבר למשתמש

### התנאי החדש לספר כפול:
ספר נחשב כפול רק אם יש ספר עם **אותו שם בדיוק** ב**אותה קטגוריה בדיוק**.
זה מאפשר לספרים עם אותו שם להיות בקטגוריות שונות מבלי להיחשב כפולים.

---

## סיכום תלויות בין שלבים

```
שלב 1 (סריקה)
    ↓
שלב 2 (פירוק נתיב)
    ↓
שלב 3 (קטגוריות) ←──┐
    ↓                │
שלב 4 (בדיקת ספר)   │
    ↓                │
┌───┴───┐            │
↓       ↓            │
שלב 5   שלב 6        │
(עדכון) (הוספה)     │
└───┬───┘            │
    ↓                │
שלב 7 (ניקוי)       │
    ↓                │
שלב 8 (אינטגרציה) ──┘
    ↓
שלב 9 (בדיקות)
```

---

## הערות למימוש

1. **Transactions** - כל פעולות הכתיבה צריכות להיות ב-transaction אחד לספר
2. **Batch Operations** - שימוש ב-batch insert לשורות (ביצועים)
3. **Error Handling** - לא למחוק קובץ אם העיבוד נכשל
4. **Logging** - תיעוד מפורט לכל פעולה לצורך debug
5. **Idempotency** - הרצה חוזרת לא תשבור את המערכת
