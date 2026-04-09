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

**הרשאה נדרשת:** `app.info.read` (למעט `app.getUserEmail` שמצריכה `app.user_email.read` - ראה למטה)

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
**הרשאה:** `app.info.read`

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

## feedback.* - משוב ומיילים

### `feedback.sendEmail`
**הרשאה:** `feedback.send_email`

שליחת משוב או דיווח למייל מותאם אישית (לא למייל דיווח השגיאות הראשי).

```javascript
const { data } = await Otzaria.call('feedback.sendEmail', {
  to: 'custom@example.com',
  subject: 'נושא המייל',
  body: 'תוכן המייל',
  includeSystemInfo: true  // אופציונלי, ברירת מחדל: false
});
// true
```

**פרמטרים:**
- `to` (חובה) - כתובת המייל של הנמען
- `subject` (חובה) - נושא המייל
- `body` (חובה) - תוכן המייל
- `includeSystemInfo` (אופציונלי) - אם `true`, מוסיף מידע מערכת (גרסה, פלטפורמה, שם התוסף) בסוף המייל

**שימושים אפשריים:**
- תוסף לשאלות ותשובות שרוצה לשלוח שאלות למייל ספציפי
- תוסף לסקרים/משוב שרוצה לאסוף תגובות
- תוסף לבקשות תכונות או דיווח באגים למפתח התוסף

---

## history.* - היסטוריית קריאה

### `history.list`
**הרשאה:** `history.read`

קבלת רשימת הספרים שנקראו לאחרונה (ללא חיפושים).

```javascript
const { data } = await Otzaria.call('history.list', {
  limit: 50  // אופציונלי, ברירת מחדל: 50
});
// [
//   { bookId: "בראשית", title: "בראשית", ref: "פרק א", index: 0, workspaceName: "לימוד יומי" },
//   { bookId: "שמות", title: "שמות", ref: "פרק ב", index: 42, workspaceName: null },
//   ...
// ]
```

### `history.listSearches`
**הרשאה:** `history.read`

קבלת רשימת החיפושים האחרונים (ללא ספרים).

```javascript
const { data } = await Otzaria.call('history.listSearches', {
  limit: 50  // אופציונלי, ברירת מחדל: 50
});
// [
//   { query: "ואהבת לרעך כמוך", ref: "...", workspaceName: "לימוד יומי" },
//   ...
// ]
```

### `history.clear`
**הרשאה:** `history.write`

ניקוי כל ההיסטוריה (ספרים וחיפושים).

```javascript
const { data } = await Otzaria.call('history.clear');
// true
```

### `history.remove`
**הרשאה:** `history.write`

מחיקת פריט ספציפי מההיסטוריה.

```javascript
const { data } = await Otzaria.call('history.remove', {
  bookId: 'בראשית',
  index: 0  // אופציונלי, אם לא מצוין - מוחק את הפריט הראשון עם bookId זה
});
// true או false
```

**שימושים אפשריים:**
- תוסף לניתוח דפוסי קריאה
- תוסף להמלצות על ספרים
- תוסף לסטטיסטיקות לימוד
- תוסף לניהול היסטוריה מתקדם

---

## notifications.* - התראות

### `notifications.showInApp`
**הרשאה:** `notifications.send`

הצגת התראה בתוך האפליקציה (UiSnack).

```javascript
const { data } = await Otzaria.call('notifications.showInApp', {
  message: 'הפעולה בוצעה בהצלחה',
  type: 'info'  // 'info' | 'success' | 'error', ברירת מחדל: 'info'
});
// true
```

**סוגי התראות:**
- `info` - הודעה רגילה (כחול)
- `success` - הודעת הצלחה (ירוק)
- `error` - הודעת שגיאה (אדום)

### `notifications.sendSystem`
**הרשאה:** `notifications.system`

שליחת התראה מיידית למערכת ההפעלה.

```javascript
const { data } = await Otzaria.call('notifications.sendSystem', {
  title: 'כותרת ההתראה',
  body: 'תוכן ההתראה',
  id: 12345  // אופציונלי, מזהה ייחודי להתראה
});
// { id: 12345 }
```

**הערות:**
- אם לא מצוין `id`, המערכת תיצור מזהה אוטומטי
- ההתראה תופיע במרכז ההתראות של מערכת ההפעלה
- דורש הרשאות מערכת (המשתמש יתבקש לאשר בפעם הראשונה)

### `notifications.scheduleSystem`
**הרשאה:** `notifications.system`

תזמון התראה למערכת ההפעלה לזמן עתידי.

```javascript
const { data } = await Otzaria.call('notifications.scheduleSystem', {
  title: 'תזכורת',
  body: 'זמן התפילה',
  scheduledTime: '2026-04-10T10:00:00Z',  // ISO 8601 format
  id: 12346  // אופציונלי
});
// { id: 12346 }
```

**הערות:**
- `scheduledTime` חייב להיות בפורמט ISO 8601
- הזמן חייב להיות בעתיד
- ההתראה תישלח אוטומטית בזמן שנקבע

### `notifications.cancel`
**הרשאה:** `notifications.system`

ביטול התראה ספציפית.

```javascript
const { data } = await Otzaria.call('notifications.cancel', {
  id: 12345
});
// true
```

### `notifications.cancelAll`
**הרשאה:** `notifications.system`

ביטול כל ההתראות של התוסף.

```javascript
const { data } = await Otzaria.call('notifications.cancelAll');
// true
```

### `notifications.checkPermissions`
**הרשאה:** `notifications.system`

בדיקת מצב הרשאות ההתראות.

```javascript
const { data } = await Otzaria.call('notifications.checkPermissions');
// { granted: true, initialized: true }
```

**שדות בתשובה:**
- `granted` - האם המשתמש אישר הרשאות התראות
- `initialized` - האם שירות ההתראות מאותחל

### `notifications.requestPermissions`
**הרשאה:** `notifications.system`

בקשת הרשאות התראות מהמשתמש.

```javascript
const { data } = await Otzaria.call('notifications.requestPermissions');
// { granted: true }
```

**הערה:** פעולה זו תציג דיאלוג למשתמש בפעם הראשונה.

**שימושים אפשריים:**
- תוסף לתזכורות לימוד
- תוסף לזמני תפילה
- תוסף לאירועי לוח שנה
- תוסף להתראות על עדכונים

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

**הרשאה נדרשת:** כל אירוע מצריך הרשאה מתאימה מסוג `events.subscribe:<event_name>`

- `plugin.boot` - נורה פעם אחת בטעינת התוסף (ללא הרשאה)
- `plugin.ready` - נורה אחרי boot (ללא הרשאה)
- `theme.changed` - שינוי בערכת הצבעים (הרשאה: `events.subscribe:theme.changed`)
- `navigation.changed` - מעבר בין מסכים ראשיים (הרשאה: `events.subscribe:navigation.changed`)
- `reader.current_book_changed` - שינוי הספר הפעיל (הרשאה: `events.subscribe:reader.current_book_changed`)
- `calendar.date_changed` - שינוי התאריך בלוח השנה (הרשאה: `events.subscribe:calendar.date_changed`)
- `workspace.changed` - שינוי סביבת העבודה (הרשאה: `events.subscribe:workspace.changed`)
- `settings.changed` - שינוי הגדרה (הרשאה: `events.subscribe:settings.changed`)
- `plugin.permissions_changed` - שינוי הרשאות (מחזיר `{ permissions: string[] }` - רשימת כל ההרשאות המאושרות) (הרשאה: `events.subscribe:plugin.permissions_changed`)

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
  
  // בדיקת הרשאות התראות
  const { data: perms } = await Otzaria.call('notifications.checkPermissions');
  if (!perms.granted) {
    await Otzaria.call('notifications.requestPermissions');
  }
  
  // שליחת התראה בתוך האפליקציה
  await Otzaria.call('notifications.showInApp', {
    message: 'התוסף נטען בהצלחה',
    type: 'success'
  });
});

// האזנה לשינוי ערכת צבעים
Otzaria.on('theme.changed', (theme) => {
  document.body.style.background = theme.colorScheme.surface;
});

// האזנה לשינוי ספר
Otzaria.on('reader.current_book_changed', async (data) => {
  console.log('ספר חדש נפתח:', data.book);
  
  // קבלת היסטוריה
  const { data: history } = await Otzaria.call('history.list', { limit: 10 });
  console.log('ספרים אחרונים:', history);
});

// דוגמה לשליחת משוב
async function sendFeedback(message) {
  try {
    await Otzaria.call('feedback.sendEmail', {
      to: 'feedback@example.com',
      subject: 'משוב על התוסף',
      body: message,
      includeSystemInfo: true
    });
    
    await Otzaria.call('notifications.showInApp', {
      message: 'המשוב נשלח בהצלחה',
      type: 'success'
    });
  } catch (error) {
    await Otzaria.call('notifications.showInApp', {
      message: 'שגיאה בשליחת המשוב',
      type: 'error'
    });
  }
}

// דוגמה לתזמון התראה
async function scheduleReminder(title, body, dateTime) {
  const { data } = await Otzaria.call('notifications.scheduleSystem', {
    title: title,
    body: body,
    scheduledTime: dateTime.toISOString()
  });
  
  console.log('התראה תוזמנה עם ID:', data.id);
  
  // שמירת ה-ID לביטול עתידי
  await Otzaria.call('storage.set', {
    key: 'reminder_id',
    value: data.id
  });
}
```

---

## רשימת הרשאות מלאה

הרשאות שתוסף יכול לבקש ב-`manifest.json`:

```json
{
  "permissions": [
    "app.info.read",
    "app.user_email.read",
    "library.books.read",
    "library.content.read",
    "search.fulltext.read",
    "reader.open",
    "navigation.write",
    "notes.read",
    "notes.write",
    "calendar.read",
    "settings.read",
    "ui.feedback",
    "plugin.storage.read",
    "plugin.storage.write",
    "published_data.write",
    "network.access",
    "feedback.send_email",
    "history.read",
    "history.write",
    "notifications.send",
    "notifications.system",
    "events.subscribe:navigation.changed",
    "events.subscribe:reader.current_book_changed",
    "events.subscribe:theme.changed",
    "events.subscribe:settings.changed",
    "events.subscribe:calendar.date_changed",
    "events.subscribe:workspace.changed",
    "events.subscribe:plugin.permissions_changed"
  ]
}
```
