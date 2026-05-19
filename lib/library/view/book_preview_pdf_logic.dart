// lib/library/view/book_preview_pdf_logic.dart
//
// ════════════════════════════════════════════════════════════════════════════
//  לוגיקת PDF preview נטו — בלי תלות ב-Widget או ב-PdfViewerController
// ════════════════════════════════════════════════════════════════════════════
//
//  הלוגיקה של [BookPreviewPanel] על PDF מורכבת משני חלקים שעדיף לבודד:
//   1. [PdfPreviewDoubleTapTracker] — מעקב אחרי שתי לחיצות עכבר עם
//      פרימרי-button בתוך kDoubleTapTimeout/kDoubleTapSlop, וזיהוי אם
//      המצביע נמצא בתוך ה"chrome" של ה-PDF (toolbar/scrollbars) אז
//      ה-double-tap לא נספר כפתיחת הספר.
//   2. [computePdfReaderTargetPage] — איזה עמוד להעביר ל-callback של
//      "פתח בעיון": העמוד הנוכחי כשה-viewer מוכן, או fallback ל-1.
//
//  שני אלה טהורים (pure), לא נשענים על Widget או על pdfrx, וקלים לבדיקה.

import 'package:flutter/gestures.dart';

/// מחשב את העמוד שאליו צריך לפתוח את הספר ב-Reader.
///
/// [viewerReady] - האם ה-PdfViewer הגיע ל-onViewerReady (controller.isReady).
/// [currentPageNumber] - העמוד הנוכחי כפי שדווח על ידי הקונטרולר, או null.
///
/// כשה-viewer לא מוכן (קובץ חסר, טרם נטען וכד'), מחזירים 1 כברירת מחדל
/// במקום לזרוק או להחזיר 0.
int computePdfReaderTargetPage({
  required bool viewerReady,
  required int? currentPageNumber,
}) {
  if (viewerReady) {
    return currentPageNumber ?? 1;
  }
  return 1;
}

/// מעקב פנימי אחרי double-click בתוך ה-PDF preview, עם כיבוד החריג של
/// chrome (toolbar/scrollbars) — לחיצה שם לא מצטרפת ל-sequence.
///
/// השימוש הוא לפי שלב:
/// ```dart
/// final tracker = PdfPreviewDoubleTapTracker();
/// // בכל PointerDown על ה-Listener:
/// if (insideChrome) {
///   tracker.reset();
///   return;
/// }
/// if (tracker.registerPointerDown(event.position)) {
///   // זה ה-click השני בתוך הטיים-אאוט → פתח את הספר
/// }
/// ```
///
/// ה-clock מוזרק דרך [now] כדי שטסטים יוכלו לשלוט בזמן.
class PdfPreviewDoubleTapTracker {
  PdfPreviewDoubleTapTracker({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _lastClickAt;
  Offset? _lastClickPosition;

  /// מאפס את ה-sequence — לקרוא כשהמצביע נכנס ל-chrome.
  void reset() {
    _lastClickAt = null;
    _lastClickPosition = null;
  }

  /// בודק אם [event] הוא candidate ל-double-tap: עכבר עם פרימרי-button.
  static bool isDoubleTapCandidate(PointerDownEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        event.buttons == kPrimaryMouseButton;
  }

  /// רושם click במיקום [position]. מחזיר `true` אם זה ה-click ה־2 בתוך
  /// [kDoubleTapTimeout] ו-[kDoubleTapSlop] — כלומר double-tap הושלם.
  ///
  /// כשמחזיר `true`, ה-state מאופס אוטומטית כדי לא לבלבל את הסקוונס הבא.
  bool registerPointerDown(Offset position) {
    final now = _now();
    if (_lastClickAt != null &&
        _lastClickPosition != null &&
        now.difference(_lastClickAt!) <= kDoubleTapTimeout &&
        (position - _lastClickPosition!).distance <= kDoubleTapSlop) {
      _lastClickAt = null;
      _lastClickPosition = null;
      return true;
    }
    _lastClickAt = now;
    _lastClickPosition = position;
    return false;
  }
}
