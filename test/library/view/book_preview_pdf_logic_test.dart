// טסטים ללוגיקה הטהורה של PDF preview שחילצנו מתוך [BookPreviewPanel].
//
// המטרה: לוודא שתי התנהגויות שלא יכולנו להוכיח דרך widget tests:
//  1. כש-PdfViewer מוכן, [computePdfReaderTargetPage] מחזירה את העמוד הנוכחי.
//  2. [PdfPreviewDoubleTapTracker] מזהה double-click רק כשמתקיימים תנאי
//     הזמן והמרחק — וכש-click נופל ב-chrome, ה-sequence מתאפס.

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/view/book_preview_pdf_logic.dart';

void main() {
  group('computePdfReaderTargetPage', () {
    test('כשה-viewer לא מוכן — מחזירה 1 (fallback)', () {
      expect(
        computePdfReaderTargetPage(viewerReady: false, currentPageNumber: 42),
        1,
        reason: 'כש-viewerReady=false, ה-pageNumber לא רלוונטי, fallback ל-1',
      );
    });

    test('כשה-viewer מוכן — מחזירה את העמוד הנוכחי', () {
      expect(
        computePdfReaderTargetPage(viewerReady: true, currentPageNumber: 7),
        7,
        reason: 'יש להעביר את העמוד הנוכחי, לא fallback',
      );
    });

    test('כשה-viewer מוכן אבל pageNumber=null — fallback ל-1', () {
      expect(
        computePdfReaderTargetPage(viewerReady: true, currentPageNumber: null),
        1,
      );
    });

    test('viewer מוכן עם pageNumber=1 — מחזירה 1 (לא fallback "מקרי")', () {
      expect(
        computePdfReaderTargetPage(viewerReady: true, currentPageNumber: 1),
        1,
      );
    });
  });

  group('PdfPreviewDoubleTapTracker.isDoubleTapCandidate', () {
    test('עכבר עם primary button — candidate', () {
      const event = PointerDownEvent(
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      expect(PdfPreviewDoubleTapTracker.isDoubleTapCandidate(event), isTrue);
    });

    test('מגע (touch) — לא candidate (פעולה ב-double-tap של GestureDetector)',
        () {
      const event = PointerDownEvent(kind: PointerDeviceKind.touch);
      expect(PdfPreviewDoubleTapTracker.isDoubleTapCandidate(event), isFalse);
    });

    test('עכבר עם secondary button (קליק ימני) — לא candidate', () {
      const event = PointerDownEvent(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      expect(PdfPreviewDoubleTapTracker.isDoubleTapCandidate(event), isFalse);
    });
  });

  group('PdfPreviewDoubleTapTracker.registerPointerDown', () {
    test('הקליק הראשון לבד אינו double-tap', () {
      final tracker = PdfPreviewDoubleTapTracker();
      expect(tracker.registerPointerDown(const Offset(10, 10)), isFalse);
    });

    test('שני קליקים באותו מיקום בתוך kDoubleTapTimeout — מזוהים כ-double-tap',
        () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = PdfPreviewDoubleTapTracker(now: () => fakeNow);

      expect(
        tracker.registerPointerDown(const Offset(100, 100)),
        isFalse,
        reason: 'הקליק הראשון רק רושם, לא מפעיל',
      );

      fakeNow = fakeNow.add(const Duration(milliseconds: 150));
      expect(
        tracker.registerPointerDown(const Offset(100, 100)),
        isTrue,
        reason: 'הקליק השני, בתוך הטיים-אאוט ובאותו מיקום — מפעיל',
      );
    });

    test('הקליק השלישי הרצוף לא נחשב כ-double-tap (ה-state התאפס אחרי השני)',
        () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = PdfPreviewDoubleTapTracker(now: () => fakeNow);

      tracker.registerPointerDown(const Offset(100, 100));
      fakeNow = fakeNow.add(const Duration(milliseconds: 150));
      tracker.registerPointerDown(const Offset(100, 100));

      fakeNow = fakeNow.add(const Duration(milliseconds: 100));
      expect(
        tracker.registerPointerDown(const Offset(100, 100)),
        isFalse,
        reason: 'אחרי double-tap, הקליק הבא הוא click חדש',
      );
    });

    test('קליק שני אחרי kDoubleTapTimeout — לא נחשב, ה-state מתעדכן לקליק חדש',
        () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = PdfPreviewDoubleTapTracker(now: () => fakeNow);

      tracker.registerPointerDown(const Offset(100, 100));

      // kDoubleTapTimeout = 300ms. מתקדמים יותר מזה.
      fakeNow = fakeNow.add(const Duration(milliseconds: 400));
      expect(
        tracker.registerPointerDown(const Offset(100, 100)),
        isFalse,
        reason: 'מעבר ל-timeout — הקליק נחשב לקליק "ראשון" חדש',
      );

      // עכשיו קליק שלישי בתוך הזמן יפעיל.
      fakeNow = fakeNow.add(const Duration(milliseconds: 100));
      expect(
        tracker.registerPointerDown(const Offset(100, 100)),
        isTrue,
        reason: 'הקליק הבא בתוך הזמן מהקליק "החדש" — כן מפעיל',
      );
    });

    test('קליק שני רחוק מ-kDoubleTapSlop — לא נחשב', () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = PdfPreviewDoubleTapTracker(now: () => fakeNow);

      tracker.registerPointerDown(const Offset(100, 100));
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));

      // kDoubleTapSlop ≈ 100 פיקסלים — מתרחקים מעבר לכך.
      expect(
        tracker.registerPointerDown(const Offset(300, 300)),
        isFalse,
        reason: 'מרחק > slop בין שני הקליקים — לא נחשב double-tap',
      );
    });

    test('reset() מוחק את הסקוונס — הקליק הבא הוא "ראשון"', () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = PdfPreviewDoubleTapTracker(now: () => fakeNow);

      tracker.registerPointerDown(const Offset(100, 100));
      tracker.reset();

      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      expect(
        tracker.registerPointerDown(const Offset(100, 100)),
        isFalse,
        reason: 'אחרי reset הקליק החדש הוא ה"ראשון" שלא מפעיל',
      );
    });

    test(
        'תרחיש מציאותי: click → click ב-chrome (reset) → click — לא double-tap',
        () {
      var fakeNow = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = PdfPreviewDoubleTapTracker(now: () => fakeNow);

      // קליק על PDF
      tracker.registerPointerDown(const Offset(100, 100));
      // click על toolbar — הקוד הקורא קורא לreset
      tracker.reset();
      // קליק על PDF — צריך להתחיל סקוונס חדש, לא לפתוח את הספר
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      expect(
        tracker.registerPointerDown(const Offset(100, 100)),
        isFalse,
        reason: 'ה-chrome קיטע — צריך לחזור לסקוונס מאפס',
      );
    });
  });
}
