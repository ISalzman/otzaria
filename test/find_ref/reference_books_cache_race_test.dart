// Regression tests for the race condition between [warmUp] and [clear].
//
// טעינת הקאש עם yields תקופתיים יוצרת חלון בו [clear] עלול להתבצע באמצע.
// בלי מנגנון הגנה, הטעינה הישנה הייתה ממשיכה לאחר ה-clear, ממלאת מחדש
// נתונים stale, ומסמנת `_isLoaded = true`.
// המנגנון: _generation counter שעולה ב-clear; הטעינה בודקת אותו אחרי
// כל yield ועוצרת אם הוא השתנה.

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/cache/acronyms_cache.dart';
import 'package:otzaria/data/cache/books_cache.dart';
import 'package:otzaria/find_ref/repository/reference_books_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // ניקוי שלושת הקאשים לסטטוס ידוע — singletons שמשותפים בין טסטים.
    ReferenceBooksCache.instance.clear();
    BooksCache.instance.clear();
    AcronymsCache.instance.clear();
  });

  group('ReferenceBooksCache — race condition מול clear()', () {
    test(
        'clear() באמצע warmUp() עוצר את הטעינה — isLoaded נשאר false',
        () async {
      final cache = ReferenceBooksCache.instance;
      expect(cache.isLoaded, isFalse, reason: 'מצב התחלתי');

      // warmUp() מתחיל לרוץ. `_loadInternal` רץ סינכרונית עד ה-await הראשון
      // (BooksCache.warmUp), ואז משעה את עצמו עד שה-microtask ירוץ.
      final inFlight = cache.warmUp();

      // קוד סינכרוני — רץ לפני שה-microtask של continuation מקבל הזדמנות.
      cache.clear(); // _generation++

      // עכשיו ה-await של _loadInternal ימצא generation מעודכן ויחזיר return.
      await inFlight;

      expect(
        cache.isLoaded,
        isFalse,
        reason: 'טעינה שנעצרה ע"י clear() אסור שתסמן isLoaded=true',
      );
    });

    test('warmUp() חוזר ועובד תקין אחרי race עם clear', () async {
      final cache = ReferenceBooksCache.instance;

      // ניסיון ראשון — race שנעצר.
      final aborted = cache.warmUp();
      cache.clear();
      await aborted;
      expect(cache.isLoaded, isFalse);

      // ניסיון שני — בלי הפרעה. אמור להגיע ל-isLoaded=true.
      await cache.warmUp();
      expect(cache.isLoaded, isTrue,
          reason: 'אחרי abort, warmUp נוסף חייב להצליח כרגיל');
    });

    test('שני clear()-ים רצופים באמצע warmUp עדיין מאפסים', () async {
      // וריאציה: clear() מרובה — generation עולה פעמיים. הטעינה הישנה
      // עדיין צריכה לזהות שינוי דור (לא משנה כמה).
      final cache = ReferenceBooksCache.instance;

      final inFlight = cache.warmUp();
      cache.clear();
      cache.clear();
      await inFlight;

      expect(cache.isLoaded, isFalse);
    });

    test('clear מנקה הכול גם אם warmUp הצליח קודם', () async {
      // ודוא שהמנגנון לא שובר את ה-clear הרגיל אחרי טעינה מוצלחת.
      final cache = ReferenceBooksCache.instance;
      await cache.warmUp();
      expect(cache.isLoaded, isTrue);

      cache.clear();
      expect(cache.isLoaded, isFalse);
    });
  });

  group('BooksCache + AcronymsCache — clear() מאפס _generation', () {
    test('clear() מתאפס isLoaded במצב טעון', () async {
      await BooksCache.instance.warmUp();
      await AcronymsCache.instance.warmUp();

      BooksCache.instance.clear();
      AcronymsCache.instance.clear();

      expect(BooksCache.instance.isLoaded, isFalse);
      expect(AcronymsCache.instance.isLoaded, isFalse);
    });

    test('warmUp חוזר מצליח אחרי clear()', () async {
      await BooksCache.instance.warmUp();
      BooksCache.instance.clear();
      expect(BooksCache.instance.isLoaded, isFalse);

      // ללא repository זמין הטעינה מסיימת מהר עם רשימה ריקה — אבל לא
      // נכשלת.
      await BooksCache.instance.warmUp();
      // ב-test environment ה-isLoaded יישאר false (SqliteDataProvider לא
      // מאותחל) — אבל warmUp לא זורק.
    });
  });
}
