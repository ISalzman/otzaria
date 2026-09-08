import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:otzaria/core/messages/window_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/core/windowing/drag_preview_colors.dart';
import 'package:otzaria/core/windowing/multi_window_service.dart';
import 'package:otzaria/core/windowing/tab_drag_preview.dart';
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

  /// ## למה המסירה מוקדמת
  ///
  /// המסירה למערכת — היחידה שפותחת את מסדר החלונות — הותנתה ביציאת הסמן
  /// מחלון המקור, וזה **כן** קורה בחלון שצמוד לראש המסך: הסמן קורא כמי
  /// שיצא בדיוק ב-`y == 0`. אבל אז אין יותר לאן לנסוע, וה-shell פותח את
  /// המסדר רק כשהחלון הנגרר **נכנס** לאזור העליון בזמן לולאת ההזזה.
  /// זה נמדד: יציאה בצד ב-`(890,134)` קיבלה מסדר חלונות, ומסירה
  /// ב-`(582,0)` לא.
  ///
  /// ## ⚠️ ומה מפריד אותה מסידור כרטיסיות
  ///
  /// **יציאה מהרצועה, ולא גאומטריה.** גרסה קודמת ניסתה להפריד לפי אזור
  /// ההתקרבות לראש הצג ולפי נסיעה מעלה, בהנחה שהאזור נשאר מעל רצועת
  /// הכרטיסיות. ההנחה שגויה: `CustomTitleBar` הוא הילד הראשון
  /// ב-`Column`, כלומר הרצועה **היא** הסרגל העליון ותופסת 0..40 יחידות
  /// לוגיות — והאזור (28) יושב בתוכה. התוצאה נמדדה בבדיקה: תפיסה בשליש
  /// התחתון של כרטיסיה וסחיפה מעלה בזמן סידור נמסרה למערכת, גרירת
  /// Flutter בוטלה, והסידור אבד. ברצועה האנכית זה גרוע יותר — שם סידור
  /// **הוא** מחווה שעולה, ומעבר של משבצת אחת (38 יחידות) עובר את סף
  /// הנסיעה בעצמו.
  ///
  /// לכן התנאי הוא [_leftStrip]: סידור כרטיסיות אינו יוצא מהרצועה
  /// לעולם, ומי שמוציא כרטיסיה כן — הוא מושך אותה משם ואז מעלה. זה גם
  /// המסלול שנמדד בלוג כשהמחווה עבדה.
  ///
  /// הנסיעה מעלה נשארת כתנאי משני, כדי ששהייה סתמית באזור אחרי יציאה
  /// מהרצועה לא תמסור. הסף עצמו מגיע מהנייטיב
  /// ([MultiWindowService.windowAtCursor]), באותן יחידות כמו האזור.
  static const MultiWindowService _service = MultiWindowService();

  /// האם הסמן יצא מרצועת הכרטיסיות במהלך הגרירה — **תנאי** למסירה
  /// המוקדמת, וההסבר המלא ליד [_service].
  ///
  /// ⚠️ "יצא בעבר" ולא "נמצא בחוץ כרגע". בחלון שצמוד לראש המסך אין שטח
  /// **מעל** הרצועה, ולכן המחווה שמוציאה כרטיסיה חוזרת אליה בדרך מעלה;
  /// דרישת "בחוץ כרגע" הייתה חוסמת בדיוק את המחווה שהתיקון נועד לה.
  bool _leftStrip = false;

  /// מזהה עולה לכל גרירה, לגידור תשובות אסינכרוניות של גרירה שהסתיימה.
  int _dragGeneration = 0;

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

  /// האם הכרטיסיה שורדת העברה. נבדק **פעם אחת** בתחילת הגרירה.
  ///
  /// ⚠️ [MultiWindowService.canTransfer] בונה כרטיסיה מלאה — BLoC,
  /// repository ומנויים — ולכן קריאה לה בלולאת הפעימות של 60ms בנתה וזרקה
  /// BLoC חדש כל 60ms לכל אורך הגרירה, בלי שום חיווי למשתמש.
  bool _transferable = true;

  /// ההודעה על כרטיסיה שאינה ניתנת להעברה כבר הוצגה.
  bool _rejectionReported = false;

  /// האם מוק החלון כבר נמסר לנייטיב.
  ///
  /// ## ⚠️ תנאי למסירה המוקדמת, ולא נוחות
  ///
  /// `SetImage` מדלג על `Compose` בזמן שלולאת ההזזה של המערכת רצה — אחרת
  /// היה משנה את גודל החלון באמצע גרירה ומזייף את חישוב ה-`snapped`.
  /// כלומר מוק שמגיע **אחרי** המסירה אינו מוצג לעולם, והמשתמש גורר את
  /// שרטוט ה-GDI: ראש כרטיסיה ב-176×40 במקום מוק של החלון.
  ///
  /// בגרירה החוצה זה לא נראה, כי עד שהסמן יוצא מהחלון הצילום מזמן הגיע.
  /// המסירה המוקדמת יורה תוך פעימות בודדות ומקדימה אותו — ולכן היא
  /// ממתינה לו. אין כאן שעון: הפעימות ממשיכות כל 60ms, והמסירה קורית
  /// בראשונה שבה גם הצילום מוכן.
  bool _snapshotSent = false;

  /// מיקום ההכנסה שהחלון היעד דיווח עליו, לשימוש בשחרור.
  int? _remoteDropIndex;

  /// הנקודה **הנמוכה** ביותר שהסמן הגיע אליה בגרירה הזו, כלומר ה-y
  /// הגדול ביותר. הנסיעה מעלה נמדדת ממנה — ראו [_upwardTravel].
  ///
  /// ⚠️ נזרע מ-[_captureDragOrigin] ולא מהפעימה הראשונה. פעימה היא 60ms
  /// אחרי תחילת הגרירה, ובזמן הזה יד זריזה עוברת חמישים פיקסלים מעלה —
  /// כלומר נקודת ההתחלה שהייתה נמדדת היא כבר אמצע הנסיעה, והנסיעה
  /// שנותרה קטנה מהסף. זה נראה בלוג: גרירה שהתחילה ברצועה נמדדה
  /// כמתחילה ב-`y=15`.
  int? _deepestCursorY;

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
    _rejectionReported = false;
    // ⚠️ מיקום הכנסה של גרירה **קודמת** אינו תקף לזו. בלי האיפוס כרטיסיה
    // נכנסה למקום שאליו כוונה הגרירה שלפניה.
    _remoteDropIndex = null;
    // ⚠️ וגם לא הנסיעה של גרירה קודמת: גרירה שהתחילה ליד ראש המסך הייתה
    // נמסרת בפעימה הראשונה, על סמך עומק שאינו שלה.
    _deepestCursorY = null;
    _leftStrip = false;
    _dragGeneration++;
    // פעם אחת לכל גרירה — ראו [_transferable].
    _transferable = MultiWindowService.canTransfer(tab);
    // ⚠️ צילום של גרירה **קודמת** אינו זה של הנוכחית, ו-`Begin` בנייטיב
    // מנקה אותו ממילא. ראו [_snapshotSent].
    _snapshotSent = false;
    // ⚠️ לפני הפעימה הראשונה — ראו [_captureDragOrigin].
    unawaited(_captureDragOrigin(_dragGeneration));
    final title = tab.title;
    // התצוגה מוצגת רק כשהסמן יוצא מחלון המקור, ולכן אין כפילות מול
    // ה-feedback של `Draggable`.
    unawaited(_service.beginTabDrag(title, colors: colors));
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  /// מחליף את השרטוט במוק של החלון. נקרא **אחרי** [begin], כשהוא מוכן.
  ///
  /// ⚠️ הבעלות על התמונה שב-[preview] עוברת לכאן — היא משוחררת גם בכשל.
  ///
  /// ⚠️ **נשלח מיד, ולא נדחה ליציאה מהחלון.** דחייה נראתה כמו חיסכון —
  /// רוב הגרירות הן סידור פנימי — אבל היא שברה שלושה דברים בבת אחת:
  ///
  /// 1. השליחה אסינכרונית, והמסירה ל-Windows מתחילה באותה פעימה. הצילום
  ///    הגיע **אחרי** שהלולאה המודאלית התחילה, ו-`SetImage` מדלג על
  ///    `Compose` בזמן גרירת מערכת — כלומר התצוגה נשארה בגודל השרטוט
  ///    (ראש הכרטיסיה בלבד) לכל אורך הגרירה.
  /// 2. `PreviewSize` מחזיר את גודל **היעד** שנקבע ב-`SetImage`, ולכן
  ///    ההשוואה בסוף הגרירה יצאה "המערכת שינתה את הגודל" — `snapped=true`
  ///    כוזב.
  /// 3. `snapped` גובר על היעד שתחת הסמן, ולכן שחרור מעל חלון אוצריא אחר
  ///    פתח חלון **חדש** במסגרת של 176×40 במקום להעביר אליו.
  void applySnapshot(TabWindowPreview preview) {
    if (!MultiWindowService.isSupported) {
      preview.image.dispose();
      return;
    }
    unawaited(_sendSnapshot(preview));
  }

  /// שולח את צילום הכרטיסיה, אם הוא באמת מכיל משהו.
  ///
  /// ⚠️ **צילום שקוף אינו נשלח.** זו לא הגנה תיאורטית: הגרסה הראשונה
  /// השתמשה ב-`toImageSync`, קיבלה תמונה ריקה, והתצוגה הראתה כרטיסיה
  /// שקופה — גרוע מהשרטוט שהיא באה להחליף. כאן ההחלטה היא לפי הפיקסלים
  /// עצמם ולא לפי הנחה על ה-API: אם אין מה להציג, השרטוט נשאר.
  Future<void> _sendSnapshot(TabWindowPreview preview) async {
    final image = preview.image;
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
      await _service.setTabDragImage(
        rgba,
        image.width,
        image.height,
        targetWidth: preview.targetWidth,
        targetHeight: preview.targetHeight,
      );
      // ⚠️ **אחרי** השליחה ולא לפניה: המסירה המוקדמת ממתינה לדגל הזה,
      // וסימונו מראש היה מתיר לה לרוץ עם צילום שעוד בדרך. ראו
      // [_snapshotSent].
      _snapshotSent = true;
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
    // צילום שלא נשלח (הגרירה נשארה בתוך החלון) אינו נחוץ יותר.
    unawaited(_service.freezeTabDrag());
  }

  /// ⚠️ חובה בסגירת החלון. הטיימר שולח בקשות אפיק כל 60ms, ולולאה שנשארה
  /// אחרי שהחלון נסגר מציפה חלונות אחרים בהודעות על גרירה שאיננה.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    // ⚠️ בלי זה הרוח הנייטיבית נשארת חיה ומצוירת אחרי שהרצועה ירדה מהעץ.
    // המסירה למערכת מנקה בעצמה, ולכן רק גרירה שלא נמסרה מטופלת כאן.
    if (_draggedTitle != null && !_handedOff) _hidePreview();
    // ⚠️ המחלקה חיה יותר מגרירה בודדת (היא שדה של הרצועה). החזקה של
    // כרטיסיה שאולי כבר `dispose`-ה היא הפניה תלויה.
    _draggedTitle = null;
    _draggedTab = null;
    _sourceBloc = null;
    _cancelFlutterDrag = null;
    _lastDragOverSlot = null;
    _remoteDropIndex = null;
    _deepestCursorY = null;
  }

  Future<void> _poll() async {
    final title = _draggedTitle;
    if (title == null || _handedOff) return;
    final target = await _service.windowAtCursor();
    // ⚠️ כשל בירור אינו "שולחן העבודה" — פשוט מדלגים על הפעימה.
    if (target == null) return;
    // ⚠️ נבדק **שוב** אחרי ה-await. הפעימה יוצאת כל 60ms והתשובה מגיעה
    // בערוץ, ולכן פעימה שיצאה כשהסמן היה מעל חלון אחר יכולה לחזור אחרי
    // שפעימה אחרת כבר מסרה את הגרירה וניקתה את החיווי — והכתיבה שלמטה
    // הייתה מדליקה אותו מחדש בחלון שכבר אינו רלוונטי, בלי שאיש יכבה.
    if (_draggedTitle == null || _handedOff) return;
    final slot = target.isSelf ? null : target.slot;

    if (_lastDragOverSlot != null && _lastDragOverSlot != slot) {
      _service.notifyDragLeave(_lastDragOverSlot!);
      _remoteDropIndex = null;
    }
    _lastDragOverSlot = slot;

    final deepest = _trackDepth(target.y);

    if (target.isSelf) {
      // ⚠️ המסלול היחיד שמוסר את הגרירה **בלי** שהסמן יצא מהחלון, והוא
      // מה שמשאיר ללולאת ההזזה נסיעה שה-shell יראה.
      //
      // שלושה תנאים, וכל אחד מהם מונע באג אחר:
      // * [_leftStrip] — מפריד מסידור כרטיסיות. ראו ההסבר שם.
      // * נסיעה מעלה — שהייה סתמית באזור אחרי יציאה מהרצועה אינה מסירה.
      // * [_snapshotSent] — בלעדיו נגרר שרטוט GDI במקום מוק החלון.
      //
      // ⚠️ כרטיסיה שאינה ניתנת להעברה פשוט **אינה נמסרת** כאן, בלי
      // הודעה. `_rejectTransfer` במסלול הזה הפך סידור מקומי של כרטיסיה
      // כזו להודעת שגיאה "אי אפשר להעביר לחלון אחר" — משפט שאינו נכון
      // על מה שהמשתמש עשה. ההודעה נשארת במסלול היציאה מהחלון, שם היא
      // כן מתארת את הכוונה.
      if (_leftStrip &&
          _transferable &&
          _snapshotSent &&
          target.approachingTop &&
          deepest - target.y >= target.minUpwardTravel) {
        await _handOffToSystem();
      }
      return;
    }

    // הסמן בחוץ: מכאן והלאה יש למי להציג את התצוגה הנייטיבית.

    // כרטיסיה שאינה ניתנת להעברה — לעצור **כאן**, עם הודעה.
    //
    // ⚠️ קודם לכן הבדיקה יושבת ב-[_handOffToSystem], שחזר בלי לסמן דבר:
    // הטיימר המשיך, וכל 60ms נבנה BLoC חדש ונזרק כל עוד הסמן בחוץ — בלי
    // שום חיווי למשתמש.
    if (!_transferable) {
      _rejectTransfer();
      return;
    }

    // ⚠️ ברגע שהסמן יצא מחלון המקור — הגרירה נמסרת ל-Windows.
    //
    // **מיד, ובלי השהיה.** גרסה קודמת השהתה 480ms כי המסירה כללה פתיחת
    // חלון, ופתיחה מוקדמת מדי הייתה שוברת העברה מחלון לחלון. עכשיו
    // המסירה אינה פותחת דבר — היא רק מעבירה למערכת חלון שכבר קיים —
    // וההחלטה לאן הכרטיסיה הולכת נופלת **בשחרור**, לפי מה שתחת הסמן.
    // כלומר אין יותר מה לשמור עליו בהשהיה.
    await _handOffToSystem();
  }

  /// מדווח שהסמן יצא מרצועת הכרטיסיות. נקרא מ-`ReadingTabStrip.onLeave`.
  ///
  /// ⚠️ זו כל ההפרדה בין סידור כרטיסיות לבין הוצאת כרטיסיה — ראו
  /// [_leftStrip]. בלעדיה סידור בחלון שצמוד לראש המסך נמסר למערכת
  /// והמחווה אבדה.
  void notePointerLeftStrip() => _leftStrip = true;

  /// מעדכן ומחזיר את הנקודה הנמוכה ביותר שהסמן הגיע אליה — ראו
  /// [_deepestCursorY].
  ///
  /// ⚠️ **הנמוכה ביותר, ולא נקודת ההתחלה.** גרירה שירדה לאזור הקריאה
  /// וחזרה מעלה היא יציאה מעלה לכל דבר, ומדידה מנקודת ההתחלה לבדה הייתה
  /// מחמיצה אותה.
  int _trackDepth(int y) {
    final deepest = _deepestCursorY;
    if (deepest == null || y > deepest) {
      _deepestCursorY = y;
      return y;
    }
    return deepest;
  }

  /// דוגם את מיקום הסמן ברגע תחילת הגרירה, לזריעת [_deepestCursorY].
  ///
  /// ⚠️ נדרש כי הפעימה הראשונה מגיעה 60ms מאוחר מדי — ראו
  /// [_deepestCursorY]. הקריאה יוצאת מ-[begin] בלי להמתין לה, והתשובה
  /// חוזרת תוך מילישניות בודדות.
  /// ⚠️ מגודר ב-[_dragGeneration] ולא רק ב-`_draggedTitle != null`.
  /// הכותרת אינה null שוב ברגע שהגרירה **הבאה** מתחילה, ולכן דגימה
  /// שיצאה בגרירה קודמת ונענתה באיחור הייתה זורעת את העומק של הגרירה
  /// ההיא — ומכיוון ש-[_trackDepth] רק מעמיק, זרע כזה מגדיל את הנסיעה
  /// הנראית ומקל על המסירה במקום להקשות.
  Future<void> _captureDragOrigin(int generation) async {
    final target = await _service.windowAtCursor();
    if (target == null || generation != _dragGeneration) return;
    _trackDepth(target.y);
  }

  /// האם [tab] ניתנת להעברה, בלי לבנות אותה מחדש כשכבר נבדקה.
  ///
  /// ⚠️ הבדיקה עצמה יקרה (ראו [MultiWindowService.canTransfer]), ולכן
  /// התוצאה של [begin] נשמרת. הנפילה-לאחור קיימת למסלול שבו [begin] לא רץ
  /// כלל — רצועה שחיברה `onDroppedOutside` בלי `onDragStarted` — ושם עדיף
  /// לשלם על בדיקה אחת מלאבד כרטיסיה.
  bool _canTransfer(OpenedTab tab) => identical(tab, _draggedTab)
      ? _transferable
      : MultiWindowService.canTransfer(tab);

  /// עוצר את הגרירה החוצה ומודיע למשתמש. פעם אחת לכל גרירה.
  void _rejectTransfer() {
    if (_rejectionReported) return;
    _rejectionReported = true;
    // ⚠️ אותו דגל של המסירה למערכת: הוא מה שמונע מ-`handleDroppedOutside`
    // לטפל בכרטיסיה שוב אחרי הביטול ששלחנו ל-Flutter.
    _handedOff = true;
    _timer?.cancel();
    _timer = null;
    final last = _lastDragOverSlot;
    if (last != null) _service.notifyDragLeave(last);
    _lastDragOverSlot = null;
    _draggedTitle = null;
    _hidePreview();
    _cancelFlutterDrag?.call();
    UiSnack.showError(WindowMessages.cannotTransferTab);
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
    if (_handedOff) return;
    final tab = _draggedTab;
    final bloc = _sourceBloc;
    // ⚠️ עוצרים את הלולאה ולא רק חוזרים. `begin` בלי `tabsBloc` היא שגיאת
    // תכנות, אבל חזרה שקטה מכאן השאירה את הטיימר פועל — כלומר פעימת ערוץ
    // ותצוגה נייטיבית שמתחדשת ב-60Hz לכל אורך הגרירה, בלי שום תוצאה.
    if (tab == null || bloc == null) {
      _handedOff = true;
      _timer?.cancel();
      _timer = null;
      _hidePreview();
      return;
    }

    _handedOff = true;
    final last = _lastDragOverSlot;
    if (last != null) _service.notifyDragLeave(last);
    _lastDragOverSlot = null;
    _draggedTitle = null;

    _cancelFlutterDrag?.call();
    final outcome = await _service.dragOutToSystem();
    _timer?.cancel();
    _timer = null;

    // `ran == false` פירושו שהנייטיב לא הריץ לולאת גרירה בכלל (למשל אין
    // תצוגה חיה). אין תוצאה להסתמך עליה, ולכן אין להעביר את הכרטיסיה.
    if (outcome == null || !outcome.ran) return _hidePreview();
    // ⚠️ נשאר בקוד. את מסלול הגרירה אי אפשר לבדוק אוטומטית — הוא תלוי
    // בהחלטות ה-shell — ושורה אחת בלוג היא ההבדל בין אבחון לניחוש.
    debugPrint(
      'גרירה הסתיימה: snapped=${outcome.snapped} '
      'rect=${outcome.left},${outcome.top} '
      '${outcome.width}×${outcome.height} '
      'slot=${outcome.slot} isSelf=${outcome.isSelf} '
      'tray=${outcome.isShellTray}',
    );

    // ⚠️ **הצמדה עוקפת את שאלת "מה תחת הסמן", וזה תיקון של באג.**
    //
    // המשתמש בחר אזור במסדר החלונות, והמערכת הצמידה את התצוגה אליו —
    // כלומר "החלון יהיה כאן" הוא כבר החלטה מפורשת. אבל האזור המוצמד מכסה
    // בדרך כלל את חלון המקור עצמו, ולכן `isSelf` יצא true והקוד ביטל
    // בשקט: המשתמש ראה את מסדר החלונות נפתח, בחר אזור, **ושום חלון לא
    // נפתח**.
    //
    // בגרירה בלי הצמדה השאלה כן רלוונטית: שם המשתמש רק הזיז את הרוח
    // ושחרר, ומה שתחת הסמן הוא כל מה שמעיד על כוונתו.
    if (!outcome.snapped) {
      // שחרור חזרה מעל חלון המקור — ביטול. אחרת כל גרירה שיצאה וחזרה
      // הייתה פותחת חלון.
      if (outcome.isSelf) return _hidePreview();

      // ⚠️ שורת המשימות אינה מחווה של "פתח חלון כאן". היא נגישה גם בחלון
      // ממוקסם, ולכן שחרור עליה הוא כמעט תמיד החטאה.
      if (outcome.isShellTray) {
        debugPrint('גרירה שוחררה מעל שורת המשימות — מבוטלת');
        return _hidePreview();
      }
    }

    if (!outcome.snapped && outcome.slot != null) {
      // הכרטיסיה נכנסת לחלון קיים — אין מה להחליף את הרוח, והיא מוסתרת
      // מיד כדי שלא תרחף מעל היעד.
      _hidePreview();
      await _transferToPeer(outcome.slot!, tab, bloc, outcome.x, outcome.y);
      return;
    }

    // כרטיסיה אחרונה בחלון: הוצאתה הייתה משאירה חלון ריק ופותחת חדש —
    // תזוזה בלי תועלת.
    if (bloc.state.tabs.length <= 1) {
      _hidePreview();
      UiSnack.show(WindowMessages.cannotTransferLastTab);
      return;
    }

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
    await _service.reportOpenWindowFailure();
  }

  /// מעביר את הכרטיסיה לחלון [slot], למקום המדויק שתחת הסמן.
  ///
  /// ⚠️ מיקום ההכנסה נשאל **כאן**, ברגע השחרור, ולא בפעימות הגרירה: מהרגע
  /// שהמסירה למערכת התחילה ה-Dart של המקור אינו מקבל עדכוני מיקום, ולכן
  /// המסלול הזה היה תמיד `index: null` — כלומר הכרטיסיה נכנסה בסוף
  /// הרצועה, גם כשהמשתמש כיוון לנקודה מסוימת בה.
  Future<void> _transferToPeer(
    int slot,
    OpenedTab tab,
    TabsBloc bloc,
    int x,
    int y,
  ) async {
    final index =
        _remoteDropIndex ??
        await _service.notifyDragOver(slot, x, y, tab.title);
    _remoteDropIndex = null;
    final moved = await _service.sendTabToWindow(slot, tab, index: index);
    if (moved == true) {
      bloc.add(RemoveTab(tab));
      return;
    }
    // החיווי ביעד הודלק על ידי `notifyDragOver` — יש לכבות אותו.
    _service.notifyDragLeave(slot);
    UiSnack.showError(
      moved == false
          ? WindowMessages.transferFailed
          : WindowMessages.transferUnconfirmed,
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
    // ⚠️ הגרירה נמסרה ל-Windows, והביטול ששלחנו ל-Flutter מגיע לכאן.
    // בלי היציאה הזו אותה כרטיסיה הייתה מטופלת פעמיים.
    if (_handedOff) return;

    final target = await _service.windowAtCursor();

    // ⚠️ כל יציאה מוקדמת מכאן חייבת להסתיר את הרוח שהוקפאה ב-[end].
    // רק המסלול שפותח חלון משאיר אותה, כדי שהיא תוחלף במשהו אמיתי.
    //
    // ⚠️ `null` הוא "לא ידוע", ולא "שולחן העבודה". שאילתה שנכשלה נראתה
    // כמו שחרור על שולחן העבודה, ולכן פתחה חלון בפינה (0,0) ומחקה את
    // הכרטיסיה מהמקור.
    if (target == null) return _hidePreview();
    if (target.isSelf) return _hidePreview();

    // ⚠️ שחרור מעל שורת המשימות אינו מחווה של "פתח חלון כאן". היא נגישה
    // גם בחלון ממוקסם, ולכן משתמש שאינו מכיר את הפיצ'ר יכול לפתוח חלון
    // שני בטעות — שינוי בהתנהגות קיימת, לא רק פיצ'ר חדש.
    if (target.isShellTray) {
      debugPrint('גרירה שוחררה מעל שורת המשימות — מבוטלת');
      return _hidePreview();
    }

    if (!_canTransfer(tab)) {
      _hidePreview();
      UiSnack.showError(WindowMessages.cannotTransferTab);
      return;
    }

    // כרטיסיה אחרונה בחלון: גרירתה החוצה הייתה משאירה חלון ריק ופותחת
    // חדש — תזוזה בלי תועלת.
    if (target.slot == null && tabsBloc.state.tabs.length <= 1) {
      _hidePreview();
      UiSnack.show(WindowMessages.cannotTransferLastTab);
      return;
    }

    if (target.slot != null) {
      // הכרטיסיה נכנסת לחלון קיים — אין מה להחליף את הרוח, והיא מוסתרת
      // מיד כדי שלא תרחף מעל היעד.
      _hidePreview();
      await _transferToPeer(
        target.slot!,
        tab,
        tabsBloc,
        target.x,
        target.y,
      );
      return;
    }

    // ⚠️ החלון נפתח **בנקודת השחרור**, והרוח נשארת שם עד שהוא נחשף.
    // עד כה הוא נפתח בהיסט מדורג מהפינה, בלי קשר למקום שאליו גררו.
    final moved = await _service.openWindow(
      tab: tab,
      // מסלול הנפילה, כשהגרירה לא נמסרה למערכת: אין תצוגה שנעצרה
      // במקום, ולכן הסמן הוא כל מה שיש.
      origin: (x: target.x, y: target.y),
    );
    if (moved) {
      tabsBloc.add(RemoveTab(tab));
      return;
    }
    _hidePreview();
    await _service.reportOpenWindowFailure();
  }

  void _hidePreview() => unawaited(_service.endTabDrag());
}
