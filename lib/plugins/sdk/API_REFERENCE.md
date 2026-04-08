# מדריך API למפתחי תוספים - אוצריא

מסמך זה מרכז את כל ה-APIs הזמינים לתוספים באוצריא.

## שימוש בסיסי

```javascript
const response = await Otzaria.call('method.name', { param: value });
if (response.success) {
  console.log(response.data);
} else {
  console.error(response.error.message);
}
```

---

## app.* - מידע על האפליקציה

**הרשאה נדרשת:** `app.info.read` (למעט `getUserEmail`)

### `app.getInfo`
מחזיר מידע על גרסת האפליקציה והפלטפורמה.

```javascript
const { data } = await Otzaria.call('app.getInfo');
// { version: "5.2.1", buildNumber: "123", platform: "windows" }
```

### `app.getTheme`
מחזיר את ערכת הצבעים והטיפוגרפיה הנוכחית.

```javascript
const { data } = await Otzaria.call('app.getTheme');
// {
//   mode: "light" | "dark",
//   colorScheme: { primary: "#6750A4", onPrimary: "#FFFFFF", ... },
//   typography: { fontFamily: "Frank Ruhl Libre", fontSize: 25, ... }
// }
```

### `app.getLocale`
מחזיר את השפה וכיוון הטקסט.

```javascript
const { data } = await Otzaria.call('app.getLocale');
// { locale: "he-IL", textDirection: "rtl" }
```

### `app.getUserEmail`
**הרשאה נדרשת:** `app.user_email.read`

מחזיר את כתובת המייל של המשתמש לזיהוי (אם הוגדרה).

```javascript
const { data } = await Otzaria.call('app.getUserEmail');
// { email: "user@example.com" } או { email: "" }
```

### `app.getGrantedPermissions`
מחזיר snapshot עדכני של ההרשאות המאושרות בפועל עבור התוסף.

```javascript
const { data } = await Otzaria.call('app.getGrantedPermissions');
// { permissions: ["app.info.read", "reader.open"] }
```

הערה: בשדה `permissions` של `plugin.boot` מתקבל snapshot בזמן העלייה בלבד. אם אתם צריכים מצב עדכני אחרי שהמשתמש שינה הרשאות, השתמשו ב-API הזה או האזינו ל-`plugin.permissions_changed`.

---

## library.* - גישה לספרייה

### `library.findBooks`
**הרשאה:** `library.books.read`

חיפוש ספרים לפי כותרת.

```javascript
const { data } = await Otzaria.call('library.findBooks', {
  query: 'רמב"ם',
  limit: 10  // אופציונלי, ברירת מחדל: 20
});
// [{ bookId: "משנה תורה", title: "משנה תורה", topics: [...] }, ...]
```

### `library.getBookMetadata`
**הרשאה:** `library.books.read`

קבלת מטא-דאטה על ספר ספציפי.

```javascript
const { data } = await Otzaria.call('library.getBookMetadata', {
  bookId: 'בראשית'
});
// { bookId: "בראשית", title: "בראשית", topics: ["תנ\"ך", "תורה"] }
```

### `library.listRecentBooks`
**הרשאה:** `library.books.read`

רשימת הספרים שנפתחו לאחרונה.

```javascript
const { data } = await Otzaria.call('library.listRecentBooks');
// [{ bookId: "בראשית", title: "בראשית", ref: "פרק א" }, ...]
```

### `library.getBookContent`
**הרשאה:** `library.content.read`

קבלת תוכן הספר (עד 5000 תווים בקריאה).

```javascript
const { data } = await Otzaria.call('library.getBookContent', {
  bookId: 'בראשית',
  offset: 0,      // אופציונלי, ברירת מחדל: 0
  limit: 2000,    // אופציונלי, ברירת מחדל: 1000, מקסימום: 5000
  section: ''     // אופציונלי, קפיצה לקטע מסוים
});
// "בראשית ברא אלהים..."
```

### `library.getBookToc`
**הרשאה:** `library.content.read`

קבלת תוכן עניינים של ספר.

```javascript
const { data } = await Otzaria.call('library.getBookToc', {
  bookId: 'בראשית'
});
// [{ text: "פרק א", index: 0, level: 1 }, ...]
```

---

## search.* - חיפוש

### `search.fullText`
**הרשאה:** `search.fulltext.read`

חיפוש טקסט מלא בכל הספרייה.

```javascript
const { data } = await Otzaria.call('search.fullText', {
  query: 'ואהבת לרעך כמוך',
  limit: 50  // אופציונלי, ברירת מחדל: 50
});
// [{ book: "ויקרא", text: "ואהבת לרעך כמוך...", index: 1234 }, ...]
```

---

## reader.* - פעולות קריאה

### `reader.openBook`
**הרשאה:** `reader.open`

פתיחת ספר במיקום מסוים.

```javascript
const { data } = await Otzaria.call('reader.openBook', {
  bookId: 'בראשית',
  index: 0,           // אופציונלי, ברירת מחדל: 0
  searchQuery: ''     // אופציונלי, הדגשת טקסט
});
// true
```

### `reader.openBookAtRef`
**הרשאה:** `reader.open`

פתיחת ספר בהתייחסות (כותרת פרק/סעיף).

```javascript
const { data } = await Otzaria.call('reader.openBookAtRef', {
  bookId: 'בראשית',
  ref: 'פרק א',
  index: 0  // אופציונלי, גיבוי אם ההתייחסות לא נמצאה
});
// true
```

### `reader.getCurrentState`
**הרשאה:** `reader.open`

קבלת מצב הקורא הנוכחי.

```javascript
const { data } = await Otzaria.call('reader.getCurrentState');
// {
//   currentBook: "בראשית",
//   currentBookId: "בראשית",
//   currentIndex: 42,
//   openTabs: [
//     { bookId: "בראשית", book: "בראשית", index: 42 },
//     { bookId: "שמות", book: "שמות", index: 0 }
//   ]
// }
```

### `reader.getCurrentRef`
**הרשאה:** `reader.open`

מחזיר את ה-reference הנוכחי של הטאב הפעיל, יחד עם הספר וה-index. אם עדיין אין reference אמין, `currentRef` יהיה `null`.

```javascript
const { data } = await Otzaria.call('reader.getCurrentRef');
// {
//   currentBook: "בראשית",
//   currentBookId: "בראשית",
//   currentIndex: 42,
//   currentRef: "בראשית פרק ג"
// }
```

### `reader.getSelection`
**הרשאה:** `reader.open`

מחזיר את הבחירה הנוכחית בטאב טקסט פעיל. אם אין בחירה פעילה, או שהטאב הפעיל אינו טאב טקסט, הערך יהיה `null`.

```javascript
const { data } = await Otzaria.call('reader.getSelection');
// {
//   text: "ויאמר אלהים",
//   start: 120,
//   end: 131,
//   currentRef: "בראשית פרק א",
//   currentBook: "בראשית",
//   currentBookId: "בראשית",
//   currentIndex: 42
// }
```

---

## navigation.* - ניווט באפליקציה

### `navigation.goTo`
**הרשאה:** `navigation.write`

מעבר למסך ראשי באפליקציה.

```javascript
const { data } = await Otzaria.call('navigation.goTo', {
  target: 'library'  // 'library' | 'reading' | 'more' | 'settings'
});
// true
```

---

## notes.* - הערות אישיות

### `notes.list`
**הרשאה:** `notes.read`

רשימת הערות לספר מסוים.

```javascript
const { data } = await Otzaria.call('notes.list', {
  bookId: 'בראשית'
});
// [{ id: "123", lineNumber: 5, content: "הערה...", contentPlain: "הערה..." }, ...]
```

### `notes.getBookNotesSummary`
**הרשאה:** `notes.read`

סיכום של כל הספרים שיש להם הערות.

```javascript
const { data } = await Otzaria.call('notes.getBookNotesSummary');
// [{ bookId: "בראשית", noteCount: 5, lastModified: "2026-04-08T10:30:00Z" }, ...]
```

### `notes.add`
**הרשאה:** `notes.write`

הוספת הערה חדשה.

```javascript
const { data } = await Otzaria.call('notes.add', {
  bookId: 'בראשית',
  lineNumber: 10,
  content: 'הערה חשובה'
});
// true
```

### `notes.update`
**הרשאה:** `notes.write`

עדכון הערה קיימת.

```javascript
const { data } = await Otzaria.call('notes.update', {
  bookId: 'בראשית',
  noteId: '123',
  content: 'הערה מעודכנת'
});
// true
```

### `notes.delete`
**הרשאה:** `notes.write`

מחיקת הערה.

```javascript
const { data } = await Otzaria.call('notes.delete', {
  bookId: 'בראשית',
  noteId: '123'
});
// true
```

---

## ui.* - ממשק משתמש

### `ui.showMessage`
**הרשאה:** `ui.feedback`

הצגת הודעה רגילה.

```javascript
await Otzaria.call('ui.showMessage', {
  message: 'הפעולה בוצעה בהצלחה'
});
```

### `ui.showSuccess`
**הרשאה:** `ui.feedback`

הצגת הודעת הצלחה.

```javascript
await Otzaria.call('ui.showSuccess', {
  message: 'הנתונים נשמרו'
});
```

### `ui.showError`
**הרשאה:** `ui.feedback`

הצגת הודעת שגיאה.

```javascript
await Otzaria.call('ui.showError', {
  message: 'אירעה שגיאה'
});
```

### `ui.showConfirm`
**הרשאה:** `ui.feedback`

הצגת דיאלוג אישור.

```javascript
const { data } = await Otzaria.call('ui.showConfirm', {
  title: 'אישור מחיקה',
  content: 'האם אתה בטוח שברצונך למחוק?'
});
// { confirmed: true } או { confirmed: false }
```

### `ui.showWarning`
**הרשאה:** `ui.feedback`

הצגת דיאלוג אזהרה (לפעולות מסוכנות).

```javascript
const { data } = await Otzaria.call('ui.showWarning', {
  title: 'אזהרה',
  content: 'פעולה זו היא בלתי הפיכה',
  subtitle: 'לא ניתן לשחזר את הנתונים'  // אופציונלי
});
// { confirmed: true } או { confirmed: false }
```

---

## storage.* - אחסון נתונים

### `storage.get`
**הרשאה:** `plugin.storage.read`

קריאת ערך שמור.

```javascript
const { data } = await Otzaria.call('storage.get', {
  key: 'myData'
});
// כל ערך JSON או null
```

### `storage.set`
**הרשאה:** `plugin.storage.write`

שמירת ערך.

```javascript
await Otzaria.call('storage.set', {
  key: 'myData',
  value: { count: 42, name: 'test' }
});
```

### `storage.remove`
**הרשאה:** `plugin.storage.write`

מחיקת ערך.

```javascript
await Otzaria.call('storage.remove', {
  key: 'myData'
});
```

### `storage.list`
**הרשאה:** `plugin.storage.read`

רשימת כל המפתחות השמורים.

```javascript
const { data } = await Otzaria.call('storage.list');
// ["myData", "settings", "cache"]
```

---

## settings.* - הגדרות אפליקציה

### `settings.get`
**הרשאה:** `settings.read`

קריאת הגדרה בודדת (רק מפתחות מורשים).

```javascript
const { data } = await Otzaria.call('settings.get', {
  key: 'key-font-size'
});
// 25
```

### `settings.getMany`
**הרשאה:** `settings.read`

קריאת מספר הגדרות בבת אחת.

```javascript
const { data } = await Otzaria.call('settings.getMany', {
  keys: ['key-font-size', 'key-font-family']
});
// { "key-font-size": 25, "key-font-family": "Frank Ruhl Libre" }
```

**מפתחות מורשים לקריאה:**
- `key-dark-mode`
- `key-follow-system-theme`
- `key-swatch-color`, `key-dark-swatch-color`
- `key-font-size`, `key-font-family`
- `key-commentators-font-family`, `key-commentators-font-size`
- `key-line-height`
- `key-selected-city`
- `key-calendar-type`
- `key-show-teamim`
- `key-default-nikud`
- `key-remove-nikud-tanach`
- `key-replace-holy-names`
- `key-library-view-mode`
- `key-align-tabs-to-right`
- `key-copy-with-headers`, `key-copy-header-format`

---

## calendar.* - לוח שנה

### `calendar.getSelectedDate`
**הרשאה:** `calendar.read`

קבלת התאריך הנבחר בלוח השנה.

```javascript
const { data } = await Otzaria.call('calendar.getSelectedDate');
// "2026-04-08T00:00:00.000Z"
```

### `calendar.getDailyTimes`
**הרשאה:** `calendar.read`

קבלת זמנים הלכתיים ליום.

```javascript
const { data } = await Otzaria.call('calendar.getDailyTimes');
// { sunrise: "06:23", sunset: "19:11", tzet: "19:45", ... }
```

### `calendar.getHalachicTimes`
**הרשאה:** `calendar.read`

קבלת זמנים הלכתיים מלאים ליום (זהה ל-`getDailyTimes`).

```javascript
const { data } = await Otzaria.call('calendar.getHalachicTimes');
// { sunrise: "06:23", sunset: "19:11", tzet: "19:45", ... }
```

### `calendar.getJewishDate`
**הרשאה:** `calendar.read`

המרת תאריך לועזי לעברי.

```javascript
const { data } = await Otzaria.call('calendar.getJewishDate');
// {
//   year: 5786,
//   month: 1,
//   day: 10,
//   gregorian: "2026-04-08T00:00:00.000Z",
//   monthName: "ניסן",
//   isLeapYear: false,
//   isShabbat: false,
//   holidays: [
//     { text: "שביעי של פסח", kind: "yomTov" }
//   ]
// }
```

שדות נוספים בתשובה:

- `monthName` - שם החודש בעברית.
- `isLeapYear` - האם השנה העברית היא שנה מעוברת.
- `isShabbat` - האם התאריך חל בשבת.
- `holidays` - רשימת חגים/ימים מיוחדים לתאריך, בפורמט `{ text, kind }`.

ערכי `kind` אפשריים:

- `yomTov`
- `roshChodesh`
- `taanit`
- `special`

### `calendar.getEvents`
**הרשאה:** `calendar.read`

קבלת אירועים לתאריך מסוים.

```javascript
const { data } = await Otzaria.call('calendar.getEvents', {
  date: '2026-04-08'  // אופציונלי, ברירת מחדל: התאריך הנבחר
});
// [{ id: "1", title: "פסח", date: "2026-04-08T00:00:00Z", description: "..." }, ...]
```

---

## publishedData.* - פרסום נתונים

### `publishedData.upsert`
**הרשאה:** `published_data.write`

פרסום או עדכון רשומה.

```javascript
await Otzaria.call('publishedData.upsert', {
  type: 'calendar.event',  // 'calendar.event' | 'saved.query' | 'note.draft' | 'reference.link' | 'tool.badge'
  scope: 'global',          // 'global' | 'workspace:<id>' | 'book:<bookId>'
  key: 'myPlugin:event1',
  payload: {
    title: 'שקיעה',
    startsAt: '2026-04-08T19:11:00+03:00',
    source: 'התוסף שלי',
    importance: 'high'
  }
});
```

### `publishedData.remove`
**הרשאה:** `published_data.write`

הסרת רשומה שפורסמה.

```javascript
await Otzaria.call('publishedData.remove', {
  type: 'calendar.event',
  scope: 'global',
  key: 'myPlugin:event1'
});
```

### `publishedData.listOwn`
**הרשאה:** `published_data.write`

רשימת כל הרשומות שפורסמו על ידי התוסף.

```javascript
const { data } = await Otzaria.call('publishedData.listOwn');
// [{ type: "calendar.event", scope: "global", key: "myPlugin:event1", payload: {...} }, ...]
```

---

## אירועים (Events)

ניתן להאזין לאירועים מהאפליקציה:

```javascript
Otzaria.on('event.name', (data) => {
  console.log('אירוע התרחש:', data);
});
```

### אירועים זמינים:

- `plugin.boot` - נורה פעם אחת בטעינת התוסף
- `plugin.ready` - נורה אחרי boot
- `theme.changed` - שינוי בערכת הצבעים
- `navigation.changed` - מעבר בין מסכים ראשיים
- `reader.current_book_changed` - שינוי הספר הפעיל
- `calendar.date_changed` - שינוי התאריך בלוח השנה
- `workspace.changed` - שינוי סביבת העבודה
- `settings.changed` - שינוי הגדרה
- `plugin.permissions_changed` - שינוי הרשאות (מחזיר `{ permissions: string[] }` - רשימת כל ההרשאות המאושרות)

---

## דוגמה מלאה

```javascript
// האזנה לטעינת התוסף
Otzaria.on('plugin.boot', async (payload) => {
  console.log('התוסף נטען:', payload.plugin.id);
  
  // החלת ערכת צבעים
  const theme = payload.theme;
  document.body.style.background = theme.colorScheme.surface;
  document.body.style.color = theme.colorScheme.onSurface;
  
  // קבלת מידע על המשתמש
  const { data: emailData } = await Otzaria.call('app.getUserEmail');
  console.log('מייל משתמש:', emailData.email);
  
  // חיפוש ספרים
  const { data: books } = await Otzaria.call('library.findBooks', {
    query: 'תנ"ך',
    limit: 5
  });
  
  books.forEach(book => {
    console.log(book.title);
  });
});

// האזנה לשינוי ערכת צבעים
Otzaria.on('theme.changed', (theme) => {
  document.body.style.background = theme.colorScheme.surface;
});
```
