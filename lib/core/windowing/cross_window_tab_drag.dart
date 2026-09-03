import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/core/windowing/drag_preview_colors.dart';
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

  /// הכרטיסיה הנגררת ובלוק הכרטיסיות של חלון המקור, למסירה מ-[_poll].
  OpenedTab? _draggedTab;
  TabsBloc? _sourceBloc;

  /// ביטול הגרירה של Flutter — ראו `_DraggableTabState._cancelDrag`.
  VoidCallback? _cancelFlutterDrag;

  /// האם הגרירה כבר נמסרה ל-Windows.
  ///
  /// ⚠️ מונע מסלול כפול. הביטול שנשלח ל-Flutter מגיע ל-`onDraggableCanceled`,
  /// כלומר [handleDroppedOutside] **כן** ייקרא — ובלי הדגל אותה כרטיסיה
  /// הייתה מטופלת פעמיים.
  bool _handedOff = false;

  Timer? _timer;

  /// החלון שקיבל את ההודעה האחרונה, כדי לנקות את החיווי כשעוזבים אותו.
  int? _lastDragOverSlot;

  /// מיקום ההכנסה שהחלון היעד דיווח עליו, לשימוש בשחרור.
  int? _remoteDropIndex;

  /// מתחיל את תצוגת הגרירה הנייטיבית ואת המעקב אחרי החלון שתחת הסמן.
  ///
  /// [colors] נלקחים מהערכה של החלון — ראו [DragPreviewColors].
  ///
  /// [tabsBloc] ו-[cancelDrag] נדרשים כדי למסור את הגרירה ל-Windows
  /// (Snap Layouts) — ראו [_handOffToSystem]. בלעדיהם הגרירה עובדת
  /// כרגיל, וההחלטה נופלת ב-[handleDroppedOutside] בלבד.
  void begin(
    OpenedTab tab,
    DragPreviewColors colors, {
    TabsBloc? tabsBloc,
    VoidCallback? cancelDrag,
  }) {
    if (!MultiWindowService.isSupported) return;
    _draggedTitle = tab.title;
    _draggedTab = tab;
    _sourceBloc = tabsBloc;
    _cancelFlutterDrag = cancelDrag;
    _handedOff = false;
    final title = tab.title;
    // התצוגה מוצגת רק כשהסמן יוצא מחלון המקור, ולכן אין כפילות מול
    // ה-feedback של `Draggable`.
    unawaited(_service.beginTabDrag(title, colors: colors));
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  /// מחליף את השרטוט בצילום הכרטיסיה. נקרא **אחרי** [begin], כשהצילום מוכן.
  ///
  /// ⚠️ הבעלות על [snapshot] עוברת לכאן — היא משוחררת גם בכשל.
  void applySnapshot(ui.Image snapshot) {
    if (!MultiWindowService.isSupported) {
      snapshot.dispose();
      return;
    }
    unawaited(_sendSnapshot(snapshot));
  }

  /// שולח את צילום הכרטיסיה, אם הוא באמת מכיל משהו.
  ///
  /// ⚠️ **צילום שקוף אינו נשלח.** זו לא הגנה תיאורטית: הגרסה הראשונה
  /// השתמשה ב-`toImageSync`, קיבלה תמונה ריקה, והתצוגה הראתה כרטיסיה
  /// שקופה — גרוע מהשרטוט שהיא באה להחליף. כאן ההחלטה היא לפי הפיקסלים
  /// עצמם ולא לפי הנחה על ה-API: אם אין מה להציג, השרטוט נשאר.
  Future<void> _sendSnapshot(ui.Image image) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return;
      final rgba = data.buffer.asUint8List();
      if (!_hasVisiblePixels(rgba)) {
        debugPrint(
          'צילום הכרטיסיה יצא שקוף (${image.width}×${image.height}) — '
          'נשאר השרטוט',
        );
        return;
      }
      await _service.setTabDragImage(rgba, image.width, image.height);
    } catch (e) {
      debugPrint('צילום הכרטיסיה לגרירה נכשל: $e');
    } finally {
      image.dispose();
    }
  }

  /// האם יש פיקסל שאינו שקוף לגמרי.
  ///
  /// ⚠️ דגימה ולא סריקה מלאה: כרטיסיה ב-DPR 1.5 היא ~10,000 פיקסלים, וזה
  /// רץ בתחילת כל גרירה. צעד של 97 (ראשוני) מבטיח שהדגימה אינה מתיישרת
  /// עם דפוס חוזר בתמונה.
  static bool _hasVisiblePixels(Uint8List rgba) {
    for (var i = 3; i < rgba.length; i += 4 * 97) {
      if (rgba[i] != 0) return true;
    }
    // הדגימה החמיצה — בדיקה מלאה לפני שמכריזים על תמונה ריקה.
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 0) return true;
    }
    return false;
  }

  /// מסיים את **המעקב**, ומשאיר את התצוגה קפואה במקום השחרור.
  ///
  /// ⚠️ `freezeTabDrag` ולא `endTabDrag`, כי בשלב הזה עוד לא ידוע אם
  /// ייפתח חלון: הסיום נורה **לפני** [handleDroppedOutside]. הסתרה מיידית
  /// השאירה את המסך ריק בדיוק בפרק הזמן שבו המשתמש מחכה לראות תוצאה —
  /// מאות מילישניות של פתיחת חלון. מי שאינו פותח חלון מסתיר במפורש.
  ///
  /// ⚠️ [_remoteDropIndex] **אינו** מתאפס כאן: השחרור צריך את המיקום.
  void end() {
    if (!MultiWindowService.isSupported) return;
    // ⚠️ הגרירה כבר בידי Windows. `freezeTabDrag` כאן היה מחזיר את הרוח
    // אחרי שהחלון האמיתי הסתיר אותה, ו-`notifyDragLeave` היה מנקה חיווי
    // של חלון שכבר אינו רלוונטי.
    if (_handedOff) return;
    _timer?.cancel();
    _timer = null;
    final last = _lastDragOverSlot;
    if (last != null) _service.notifyDragLeave(last);
    _lastDragOverSlot = null;
    _draggedTitle = null;
    unawaited(_service.freezeTabDrag());
  }

  /// ⚠️ חובה בסגירת החלון. הטיימר שולח בקשות אפיק כל 60ms, ולולאה שנשארה
  /// אחרי שהחלון נסגר מציפה חלונות אחרים בהודעות על גרירה שאיננה.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final title = _draggedTitle;
    if (title == null || _handedOff) return;
    final target = await _service.windowAtCursor();
    final slot = target.isSelf ? null : target.slot;

    if (_lastDragOverSlot != null && _lastDragOverSlot != slot) {
      _service.notifyDragLeave(_lastDragOverSlot!);
      _remoteDropIndex = null;
    }
    _lastDragOverSlot = slot;

    // ⚠️ ברגע שהסמן יצא מחלון המקור — הגרירה נמסרת ל-Windows.
    //
    // **מיד, ובלי השהיה.** גרסה קודמת השהתה 480ms כי המסירה כללה פתיחת
    // חלון, ופתיחה מוקדמת מדי הייתה שוברת העברה מחלון לחלון. עכשיו
    // המסירה אינה פותחת דבר — היא רק מעבירה למערכת חלון שכבר קיים —
    // וההחלטה לאן הכרטיסיה הולכת נופלת **בשחרור**, לפי מה שתחת הסמן.
    // כלומר אין יותר מה לשמור עליו בהשהיה.
    if (!target.isSelf) {
      await _handOffToSystem();
      return;
    }

    if (slot == null) return;

    _remoteDropIndex = await _service.notifyDragOver(
      slot,
      target.x,
      target.y,
      title,
    );
  }

  /// מוסר את הגרירה ל-Windows, ומטפל בתוצאה כשהמשתמש שחרר.
  ///
  /// ## למה זו הדרך היחידה ל-Snap Layouts
  ///
  /// "גרירת כרטיסייה החוצה לא מקפיצה את מסדר החלונות" — ובצדק: עד כאן,
  /// מבחינת Windows, שום חלון לא נגרר. הסמן לכוד בתהליך שלנו, וה-runner
  /// מזיז חלון layered בטיימר. אין API שפותח את מסדר החלונות; ה-shell
  /// פותח אותו בעצמו, ורק כשהוא משוכנע שנגרר **חלון**.
  ///
  /// לכן התצוגה עצמה — צילום הכרטיסיה — היא חלון עם סגנונות של חלון
  /// אמיתי, והיא זו שנמסרת למערכת.
  ///
  /// ## ⚠️ שום חלון אוצריא אינו נפתח כאן
  ///
  /// זו נקודת התיקון מול הגרסה הקודמת, שפתחה מנוע Flutter מלא באמצע
  /// הגרירה — ובצדק נדחתה. מה שנגרר הוא חלון Win32 ריק שכבר קיים,
  /// והחלון האמיתי נפתח **רק בשחרור**, על פי המסגרת שהמשתמש עצר בה.
  ///
  /// ## למה `_cancelFlutterDrag`
  ///
  /// מהרגע שלולאת ההזזה של Windows לוכדת את העכבר, Flutter לא יראה את
  /// השחרור — ה-`Draggable` היה נשאר תקוע לנצח, עם הכרטיסיה מעומעמת
  /// במקומה. הביטול מסתיים ב-`onDraggableCanceled`, כמו כל גרירה
  /// שהתפספסה, ומשם [_handedOff] מונע טיפול כפול.
  Future<void> _handOffToSystem() async {
    final tab = _draggedTab;
    final bloc = _sourceBloc;
    if (tab == null || bloc == null || _handedOff) return;

    // ⚠️ נבדק **לפני** המסירה. כרטיסיה שאינה שורדת סריאליזציה תיפול בכל
    // מקרה, ועדיף שהמסלול הרגיל יציג את השגיאה מאשר שהגרירה תיעלם
    // ללולאה מודאלית ותחזור בלי כלום.
    if (!MultiWindowService.canTransfer(tab)) return;

    _handedOff = true;
    final last = _lastDragOverSlot;
    if (last != null) _service.notifyDragLeave(last);
    _lastDragOverSlot = null;
    _draggedTitle = null;

    _cancelFlutterDrag?.call();
    final outcome = await _service.dragOutToSystem();
    _timer?.cancel();
    _timer = null;

    if (outcome == null) return _hidePreview();

    // שחרור חזרה מעל חלון המקור — ביטול. אחרת כל גרירה שיצאה וחזרה
    // הייתה פותחת חלון.
    if (outcome.isSelf) return _hidePreview();

    // ⚠️ שורת המשימות אינה מחווה של "פתח חלון כאן". היא נגישה גם בחלון
    // ממוקסם, ולכן שחרור עליה הוא כמעט תמיד החטאה.
    if (outcome.isShellTray) {
      debugPrint('גרירה שוחררה מעל שורת המשימות — מבוטלת');
      return _hidePreview();
    }

    final dropIndex = _remoteDropIndex;
    _remoteDropIndex = null;

    if (outcome.slot != null) {
      // הכרטיסיה נכנסת לחלון קיים — אין מה להחליף את הרוח, והיא מוסתרת
      // מיד כדי שלא תרחף מעל היעד.
      _hidePreview();
      final moved = await _service.sendTabToWindow(
        outcome.slot!,
        tab,
        index: dropIndex,
      );
      if (moved) {
        bloc.add(RemoveTab(tab));
      } else {
        UiSnack.showError('העברת הכרטיסיה נכשלה');
      }
      return;
    }

    // כרטיסיה אחרונה בחלון: הוצאתה הייתה משאירה חלון ריק ופותחת חדש —
    // תזוזה בלי תועלת.
    if (bloc.state.tabs.length <= 1) return _hidePreview();

    // ⚠️ מסגרת מדויקת **רק** אחרי הצמדה. התצוגה היא בגודל כרטיסיה, ולכן
    // שימוש עיוור במסגרת שלה היה יוצר חלון אוצריא של 176×40.
    //
    // בלי הצמדה עוברת **הפינה שבה התצוגה נעצרה** — כלומר המקום שבו
    // המשתמש ראה את הכרטיסיה ברגע השחרור, ולא מיקום הסמן. השניים אינם
    // זהים, והשימוש בסמן הוא מה שהוליד את "גררתי ימינה והחלון נפתח
    // בשמאל": ה-runner הזיז את החלון `-width + 100` מהסמן.
    final moved = await _service.openWindow(
      tab: tab,
      origin: outcome.snapped ? null : (x: outcome.left, y: outcome.top),
      bounds: outcome.snapped
          ? (
              left: outcome.left,
              top: outcome.top,
              width: outcome.width,
              height: outcome.height,
            )
          : null,
    );
    if (moved) {
      bloc.add(RemoveTab(tab));
      return;
    }

    _hidePreview();
    final info = await _service.windowCount();
    if (info.count >= info.max) {
      UiSnack.show(
        'אפשר לפתוח עד ${info.max} חלונות. סגור חלון כדי לפתוח חדש.',
      );
    } else {
      UiSnack.showError('פתיחת החלון נכשלה');
    }
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
    // ⚠️ הגרירה נמסרה ל-Windows, והביטול ששלחנו ל-Flutter מגיע לכאן.
    // בלי היציאה הזו אותה כרטיסיה הייתה מטופלת פעמיים.
    if (_handedOff) return;

    final target = await _service.windowAtCursor();

    // ⚠️ כל יציאה מוקדמת מכאן חייבת להסתיר את הרוח שהוקפאה ב-[end].
    // רק המסלול שפותח חלון משאיר אותה, כדי שהיא תוחלף במשהו אמיתי.
    if (target.isSelf) return _hidePreview();

    // ⚠️ שחרור מעל שורת המשימות אינו מחווה של "פתח חלון כאן". היא נגישה
    // גם בחלון ממוקסם, ולכן משתמש שאינו מכיר את הפיצ'ר יכול לפתוח חלון
    // שני בטעות — שינוי בהתנהגות קיימת, לא רק פיצ'ר חדש.
    if (target.isShellTray) {
      debugPrint('גרירה שוחררה מעל שורת המשימות — מבוטלת');
      return _hidePreview();
    }

    // ⚠️ נבדק לפני כל ניסיון העברה. כרטיסיה שאינה שורדת סריאליזציה הייתה
    // נעלמת מכאן ולא נפתחת שם.
    if (!MultiWindowService.canTransfer(tab)) {
      _hidePreview();
      UiSnack.showError('לא ניתן להעביר את הכרטיסיה הזו לחלון אחר');
      return;
    }

    // כרטיסיה אחרונה בחלון: גרירתה החוצה הייתה משאירה חלון ריק ופותחת
    // חדש — תזוזה בלי תועלת.
    if (target.slot == null && tabsBloc.state.tabs.length <= 1) {
      return _hidePreview();
    }

    // מיקום ההכנסה שהחלון היעד דיווח עליו בזמן הגרירה — כך השחרור על
    // רצועת הכרטיסיות שלו ממזג למקום מדויק ולא רק מוסיף בסוף.
    final dropIndex = _remoteDropIndex;
    _remoteDropIndex = null;

    final bool moved;
    if (target.slot != null) {
      // הכרטיסיה נכנסת לחלון קיים — אין מה להחליף את הרוח, והיא מוסתרת
      // מיד כדי שלא תרחף מעל היעד.
      _hidePreview();
      moved = await _service.sendTabToWindow(
        target.slot!,
        tab,
        index: dropIndex,
      );
    } else {
      // ⚠️ החלון נפתח **בנקודת השחרור**, והרוח נשארת שם עד שהוא נחשף.
      // עד כה הוא נפתח בהיסט מדורג מהפינה, בלי קשר למקום שאליו גררו.
      moved = await _service.openWindow(
        tab: tab,
        // מסלול הנפילה, כשהגרירה לא נמסרה למערכת: אין תצוגה שנעצרה
        // במקום, ולכן הסמן הוא כל מה שיש.
        origin: (x: target.x, y: target.y),
      );
      if (!moved) _hidePreview();
    }

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

  void _hidePreview() => unawaited(_service.endTabDrag());
}
