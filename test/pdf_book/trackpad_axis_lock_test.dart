import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/utils/trackpad_axis_lock.dart';

void main() {
  // שעון בקרה: מאפשר לקדם את הזמן בטסטים בלי להמתין בפועל.
  late DateTime fakeNow;
  DateTime clock() => fakeNow;

  PointerScrollEvent scrollEvent(double dx, double dy) {
    return PointerScrollEvent(
      timeStamp: Duration.zero,
      kind: PointerDeviceKind.trackpad,
      device: 1,
      position: const Offset(100, 100),
      scrollDelta: Offset(dx, dy),
    );
  }

  setUp(() {
    fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
  });

  group('TrackpadAxisLock - נעילה ראשונית', () {
    test('delta אנכי דומיננטי נועל את הציר לאנכי ומאפס את ה-dx', () {
      final lock = TrackpadAxisLock(clock: clock);
      final result = lock.apply(scrollEvent(3, 20)) as PointerScrollEvent;

      expect(lock.lockedAxis, Axis.vertical);
      expect(result.scrollDelta, const Offset(0, 20));
    });

    test('delta אופקי דומיננטי נועל את הציר לאופקי ומאפס את ה-dy', () {
      final lock = TrackpadAxisLock(clock: clock);
      final result = lock.apply(scrollEvent(25, 4)) as PointerScrollEvent;

      expect(lock.lockedAxis, Axis.horizontal);
      expect(result.scrollDelta, const Offset(25, 0));
    });

    test('שוויון מוחלט נועל לאנכי (ברירת מחדל בקריאת PDF)', () {
      final lock = TrackpadAxisLock(clock: clock);
      final result = lock.apply(scrollEvent(10, 10)) as PointerScrollEvent;

      expect(lock.lockedAxis, Axis.vertical);
      expect(result.scrollDelta, const Offset(0, 10));
    });

    test('delta אפסי לא קובע ציר ומוחזר כמו שהוא', () {
      final lock = TrackpadAxisLock(clock: clock);
      final event = scrollEvent(0, 0);
      final result = lock.apply(event);

      expect(lock.lockedAxis, isNull);
      expect(identical(result, event), isTrue);
    });
  });

  group('TrackpadAxisLock - שמירת נעילה ברצף', () {
    test('אירועים רצופים שומרים על הציר הנעול גם אם הציר השני מתחזק', () {
      final lock = TrackpadAxisLock(clock: clock);

      lock.apply(scrollEvent(2, 15));
      expect(lock.lockedAxis, Axis.vertical);

      // אחרי 50ms - בתוך החלון הרציף.
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      final result = lock.apply(scrollEvent(30, 5)) as PointerScrollEvent;

      // הציר נשאר אנכי למרות שעכשיו dx גדול יותר.
      expect(lock.lockedAxis, Axis.vertical);
      expect(result.scrollDelta, const Offset(0, 5));
    });

    test('גלילה ברצף בציר הנעול מחזירה את האירוע המקורי ללא שינוי', () {
      final lock = TrackpadAxisLock(clock: clock);
      lock.apply(scrollEvent(0, 20));

      fakeNow = fakeNow.add(const Duration(milliseconds: 30));
      final event = scrollEvent(0, 25);
      final result = lock.apply(event);

      // אין שינוי - מחזיר את אותו אירוע (אופטימיזציה).
      expect(identical(result, event), isTrue);
    });
  });

  group('TrackpadAxisLock - שחרור אחרי הפסקה', () {
    test('אחרי הפסקה > idleReset הנעילה משתחררת', () {
      final lock = TrackpadAxisLock(
        clock: clock,
        idleReset: const Duration(milliseconds: 150),
      );

      lock.apply(scrollEvent(0, 20));
      expect(lock.lockedAxis, Axis.vertical);

      // הפסקה ארוכה = הרמת אצבעות.
      fakeNow = fakeNow.add(const Duration(milliseconds: 200));
      final result = lock.apply(scrollEvent(30, 2)) as PointerScrollEvent;

      // ננעל מחדש - הפעם לאופקי.
      expect(lock.lockedAxis, Axis.horizontal);
      expect(result.scrollDelta, const Offset(30, 0));
    });

    test('הפסקה השווה ל-idleReset בדיוק עדיין נחשבת רצף', () {
      final lock = TrackpadAxisLock(
        clock: clock,
        idleReset: const Duration(milliseconds: 150),
      );

      lock.apply(scrollEvent(0, 20));

      fakeNow = fakeNow.add(const Duration(milliseconds: 150));
      lock.apply(scrollEvent(30, 5));

      // הציר נשאר אנכי כי הפער == idleReset (לא גדול ממנו).
      expect(lock.lockedAxis, Axis.vertical);
    });
  });

  group('TrackpadAxisLock - מקרי קצה', () {
    test('Ctrl לחוץ - האירוע עובר ללא שינוי והנעילה מתאפסת', () {
      final lock = TrackpadAxisLock(clock: clock);
      lock.apply(scrollEvent(0, 20));
      expect(lock.lockedAxis, Axis.vertical);

      final event = scrollEvent(5, 15);
      final result = lock.apply(event, isControlPressed: true);

      expect(identical(result, event), isTrue);
      expect(lock.lockedAxis, isNull);
    });

    test('אירוע שאינו PointerScrollEvent מוחזר כמו שהוא', () {
      final lock = TrackpadAxisLock(clock: clock);
      final event = const PointerScaleEvent(
        position: Offset(100, 100),
        scale: 1.2,
      );

      final result = lock.apply(event);
      expect(identical(result, event), isTrue);
      expect(lock.lockedAxis, isNull);
    });

    test('reset() מאפסת את המצב הפנימי', () {
      final lock = TrackpadAxisLock(clock: clock);
      lock.apply(scrollEvent(0, 20));
      expect(lock.lockedAxis, Axis.vertical);

      lock.reset();
      expect(lock.lockedAxis, isNull);

      // האירוע הבא ננעל מחדש.
      final result = lock.apply(scrollEvent(30, 2)) as PointerScrollEvent;
      expect(lock.lockedAxis, Axis.horizontal);
      expect(result.scrollDelta, const Offset(30, 0));
    });
  });

  group('TrackpadAxisLock - תרחיש משולב', () {
    test('גלילה אנכית, הפסקה, גלילה אופקית, הפסקה, גלילה אנכית', () {
      final lock = TrackpadAxisLock(
        clock: clock,
        idleReset: const Duration(milliseconds: 150),
      );

      // שלב 1: גלילה אנכית ארוכה - המשתמש גולל למטה ואצבעותיו זזות
      // קצת לצדדים תוך כדי. הציר נשאר נעול לאנכי.
      var result = lock.apply(scrollEvent(0, 20)) as PointerScrollEvent;
      expect(result.scrollDelta, const Offset(0, 20));

      fakeNow = fakeNow.add(const Duration(milliseconds: 30));
      result = lock.apply(scrollEvent(8, 18)) as PointerScrollEvent;
      expect(result.scrollDelta, const Offset(0, 18));

      fakeNow = fakeNow.add(const Duration(milliseconds: 30));
      result = lock.apply(scrollEvent(12, 15)) as PointerScrollEvent;
      expect(result.scrollDelta, const Offset(0, 15));

      // שלב 2: המשתמש מרים אצבעות (הפסקה ארוכה) ומתחיל גלילה אופקית.
      fakeNow = fakeNow.add(const Duration(milliseconds: 500));
      result = lock.apply(scrollEvent(25, 3)) as PointerScrollEvent;
      expect(lock.lockedAxis, Axis.horizontal);
      expect(result.scrollDelta, const Offset(25, 0));

      // שלב 3: שוב הרמת אצבעות, ומתחיל גלילה אנכית.
      fakeNow = fakeNow.add(const Duration(milliseconds: 500));
      result = lock.apply(scrollEvent(2, 30)) as PointerScrollEvent;
      expect(lock.lockedAxis, Axis.vertical);
      expect(result.scrollDelta, const Offset(0, 30));
    });
  });

  group('pdfPanAxis - מדיניות ציר ה-pan של הצפיין (issue #821)', () {
    test('בדסקטופ ננעל לציר - מחוות pan מגיעות רק מלוח מגע', () {
      expect(pdfPanAxis(isMobile: false), PanAxis.aligned);
    });

    test('במגע גרירה ישירה נשארת חופשית', () {
      expect(pdfPanAxis(isMobile: true), PanAxis.free);
    });
  });
}
