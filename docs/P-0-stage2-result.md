
---

## נספח י' — P-0 שלב 2: מנוע ללא view **עובד**. C1 אפשרי.

שלב 1 פסל את B. שלב 2 שואל אם C1 אפשרי — ותשובתו נמדדה.

### י'-1. מה נמדד

`otzaria.exe --role=broker` יוצר `flutter::FlutterEngine` **בלי**
`FlutterViewController` — כמו `examples/multiple_windows` של Flutter — עם
נקודת כניסה `brokerMain`. אין חלון, אין `RegisterPlugins`, אין ערוצים.

⚠️ זה **אינו** ה-`headless` הקיים בקוד: הוא יוצר view מלא ורק מדלג על ההצגה.

הרצה על עותק הבדיקה (8GB ספרים + אינדקס), במצב נייד:

```
[broker] engine-alive                  = yes
[broker] timer                         = fired
[broker] microtask                     = ran
[broker] file-io                       = 1712640 bytes
[broker] rootBundle:AssetManifest.bin  = ok (7291 bytes)
[broker] rootBundle:app-asset          = ok (20663 chars)
[broker] settings-init                 = ok
[broker] hive                          = ok
[broker] sqlite                        = ok
[broker] rustlib-init                  = ok
[broker] tantivy                       = ok (engine open, 90047 hits)
[broker] rss-mb                        = 460
```

### י'-2. ארבע מסקנות

1. **מנוע ללא view מריץ Dart במלואו.** טיימרים, microtasks ו-I/O פועלים.
   זה סוגר את אי-הוודאות המרכזית של **T-G2.0**: העובדה ש-`ProcessMessages`
   הוא no-op אינה מפריעה, כי `TaskRunnerWindow` המשותף ולולאת `GetMessage`
   מזינים את המנוע. **חלופה A של T-G2.0 (engine ללא view) מאושרת** — ואין
   צורך בחלופה B (חלון cloaked) על שלושת סיכוניה.

2. **`rootBundle` עובד.** זו ההכרעה בין C1 ל-C2 (§3.4.1): **C1 אפשרי,
   ו-C2 — חילוץ `otzaria_data` ל-package נפרד — מיותר.** `tantivy_data_provider`
   יכול להישאר כפי שהוא.

3. **שלושת מאגרי הנתונים נפתחים בתהליך ללא view:** Hive, SQLite ואינדקס
   Tantivy (90,047 תוצאות לשאילתת בדיקה). **בדיקה 11 של שלב 2 עברה במלואה.**

4. **אין צורך בתוספים.** ה-broker לא קרא ל-`RegisterPlugins` כלל, ובכל
   זאת הכול נפתח — Hive ו-SQLite אינם עוברים בערוצי פלטפורמה. זה מאשש את
   תכנון **T-G2.4** (`RegisterHostPlugins` עם רשימה ריקה או כמעט ריקה),
   ומייתר את החשש משלושת התוספים שקורסים בלי view.

**RSS: 460MB** לתהליך broker שמחזיק את שלושת המאגרים. נתון בסיס ל-P-2
סעיף 9; לשם השוואה, מופע UI מלא באותה ספרייה הגיע ל-2032MB.

### י'-3. שתי מלכודות מדידה שנתפסו תוך כדי

שתיהן היו מדווחות ככשל של הארכיטקטורה אילו לא נבדקו:

* **`rootBundle` "נכשל"** — טעות שלי: ביקשתי `AssetManifest.bin.json`,
  שאינו קיים. השם הנכון הוא `AssetManifest.bin`. עם השם הנכון, ועם נכס
  אמיתי של האפליקציה, הטעינה עוברת.
* **Tantivy "נכשל"** — `flutter_rust_bridge has not been initialized`.
  לא כשל של המנוע חסר-view אלא השמטה: `main()` קורא ל-`RustLib.init()`,
  והמדידה לא. עם הקריאה, האינדקס נפתח.

**הלקח לכל מי שיריץ מדידות בהמשך:** כשל בספייק הוא קודם כול חשד לטעות
בספייק. הודעת שגיאה שנראית ארכיטקטונית ("המנוע לא תומך") הייתה כאן
פעמיים שגיאת הרצה פשוטה.

### י'-4. מה עוד לא נמדד

בדיקות 12-16 של שלב 2 — named pipe עם ACL, ביטול, timeout, קריסת broker,
שני brokers, וניקוי יתומים — **לא הורצו.** הן שייכות ל-transport ולניהול
מחזור החיים, ולא לשאלה "האם C1 אפשרי" שנענתה כאן.

תקציבי הביצועים (בדיקה 13) גם הם טרם נמדדו; הם דורשים broker עם RPC פעיל.
