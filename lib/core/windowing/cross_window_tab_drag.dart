import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/core/windowing/multi_window_service.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/tab.dart';

/// גרירת כרטיסיה **מחוץ** לחלון: לחלון אוצריא אחר, או אל שולחן העבודה.
///
/// ⚠️ מחלקה אחת לשתי הרצועות, ובמכוון. ההיגיון הזה נכתב תחילה בתוך
/// `custom_title_bar` בלבד, והרצועה האנכית פשוט לא חוברה — היא **כן** יכלה
/// לקלוט כרטיסיות מחלונות אחרים, ולכן הפיצ'ר היה חד-כיווני בשקט: מקבל אך
/// לא שולח. משתמש שעבד עם כרטיסיות בצד קיבל חצי תכונה בלי שאיש הצהיר על כך.
///
/// Flutter אינו יודע דבר מחוץ לחלון שלו, ולכן שני חלקים נייטיביים מגשרים:
/// תצוגת הגרירה (`beginTabDrag`) וזיהוי מה נמצא תחת הסמן (`windowAtCursor`).
class CrossWindowTabDrag {
  /// ⚠️ קצב קבוע ולא `onDragUpdate`: `Draggable` מדווח עשרות עדכונים
  /// בשנייה, וכל אחד היה קריאת ערוץ ובקשת אפיק. 60ms מספיקים כדי שהחיווי
  /// ירגיש רציף, ומורידים את התעבורה בסדר גודל.
  static const Duration _pollInterval = Duration(milliseconds: 60);

  static const MultiWindowService _service = MultiWindowService();

  /// כותרת הכרטיסיה הנגררת כרגע, לשליחה לחלון היעד.
  String? _draggedTitle;

  Timer? _timer;

  /// החלון שקיבל את ההודעה האחרונה, כדי לנקות את החיווי כשעוזבים אותו.
  int? _lastDragOverSlot;

  /// מיקום ההכנסה שהחלון היעד דיווח עליו, לשימוש בשחרור.
  int? _remoteDropIndex;

  /// מתחיל את תצוגת הגרירה הנייטיבית ואת המעקב אחרי החלון שתחת הסמן.
  void begin(String title) {
    if (!MultiWindowService.isSupported) return;
    _draggedTitle = title;
    // התצוגה מוצגת רק כשהסמן יוצא מהחלון, ולכן אין כפילות מול ה-feedback
    // של `Draggable`.
    unawaited(_service.beginTabDrag(title));
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  /// מסיים את הגרירה בכל מסלולי הסיום — כולל ביטול, אחרת התצוגה נשארת
  /// תלויה על המסך.
  ///
  /// ⚠️ [_remoteDropIndex] **אינו** מתאפס כאן: הסיום נורה לפני השחרור,
  /// והשחרור צריך את המיקום.
  void end() {
    if (!MultiWindowService.isSupported) return;
    _timer?.cancel();
    _timer = null;
    final last = _lastDragOverSlot;
    if (last != null) _service.notifyDragLeave(last);
    _lastDragOverSlot = null;
    _draggedTitle = null;
    unawaited(_service.endTabDrag());
  }

  /// ⚠️ חובה בסגירת החלון. הטיימר שולח בקשות אפיק כל 60ms, ולולאה שנשארה
  /// אחרי שהחלון נסגר מציפה חלונות אחרים בהודעות על גרירה שאיננה.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final title = _draggedTitle;
    if (title == null) return;
    final target = await _service.windowAtCursor();
    final slot = target.isSelf ? null : target.slot;

    if (_lastDragOverSlot != null && _lastDragOverSlot != slot) {
      _service.notifyDragLeave(_lastDragOverSlot!);
      _remoteDropIndex = null;
    }
    _lastDragOverSlot = slot;
    if (slot == null) return;

    _remoteDropIndex = await _service.notifyDragOver(
      slot,
      target.x,
      target.y,
      title,
    );
  }

  /// כרטיסיה שוחררה מחוץ לכל יעד הפלה — ייתכן מחוץ לחלון.
  ///
  /// ⚠️ Flutter אינו יודע דבר מחוץ לחלון שלו, ולכן השאלה "לאן שוחררה"
  /// נשאלת מ-Win32: מה נמצא תחת הסמן ברגע השחרור.
  ///
  /// ארבע תוצאות:
  /// * מעל החלון הזה עצמו — שחרור בתוך החלון שלא פגע ביעד. אין לעשות דבר,
  ///   אחרת כל גרירה שהתפספסה הייתה פותחת חלון.
  /// * מעל שורת המשימות — ביטול. ראו [_service.windowAtCursor].
  /// * מעל חלון אוצריא אחר — הכרטיסיה עוברת אליו.
  /// * מעל שולחן העבודה או תוכנה אחרת — נפתח חלון חדש, כמו בדפדפן.
  Future<void> handleDroppedOutside(OpenedTab tab, TabsBloc tabsBloc) async {
    final target = await _service.windowAtCursor();
    if (target.isSelf) return;

    // ⚠️ שחרור מעל שורת המשימות אינו מחווה של "פתח חלון כאן". היא נגישה
    // גם בחלון ממוקסם, ולכן משתמש שאינו מכיר את הפיצ'ר יכול לפתוח חלון
    // שני בטעות — שינוי בהתנהגות קיימת, לא רק פיצ'ר חדש.
    if (target.isShellTray) {
      debugPrint('גרירה שוחררה מעל שורת המשימות — מבוטלת');
      return;
    }

    // ⚠️ נבדק לפני כל ניסיון העברה. כרטיסיה שאינה שורדת סריאליזציה הייתה
    // נעלמת מכאן ולא נפתחת שם.
    if (!MultiWindowService.canTransfer(tab)) {
      UiSnack.showError('לא ניתן להעביר את הכרטיסיה הזו לחלון אחר');
      return;
    }

    // כרטיסיה אחרונה בחלון: גרירתה החוצה הייתה משאירה חלון ריק ופותחת
    // חדש — תזוזה בלי תועלת.
    if (target.slot == null && tabsBloc.state.tabs.length <= 1) return;

    // מיקום ההכנסה שהחלון היעד דיווח עליו בזמן הגרירה — כך השחרור על
    // רצועת הכרטיסיות שלו ממזג למקום מדויק ולא רק מוסיף בסוף.
    final dropIndex = _remoteDropIndex;
    _remoteDropIndex = null;

    final moved = target.slot != null
        ? await _service.sendTabToWindow(target.slot!, tab, index: dropIndex)
        : await _service.openWindow(tab: tab);

    if (moved) {
      tabsBloc.add(RemoveTab(tab));
      return;
    }
    final info = await _service.windowCount();
    if (info.count >= info.max) {
      UiSnack.show(
        'אפשר לפתוח עד ${info.max} חלונות. סגור חלון כדי לפתוח חדש.',
      );
    } else {
      UiSnack.showError('העברת הכרטיסיה נכשלה');
    }
  }
}
