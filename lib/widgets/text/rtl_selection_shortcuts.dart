import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// דגל "priming" פעיל: בזמן שהוא true, שינויי הבחירה הם זמניים (פקודות-הכנה
/// לנעילת קצה ה-focus) ואין לעבד אותם ב-`onSelectionChanged` של האפליקציה
/// (שמירת טקסט/סנכרון/prefetch). מטפלי הבחירה בודקים אותו ויוצאים מוקדם.
bool rtlSelectionPriming = false;

// --- מעקב כיוון גרירת הבחירה (לזיהוי קצה ה-focus) ---
// `selectionEndpoints` הציבורי ממיין לפי Y, ולכן בבחירה רב-שורתית אי אפשר
// לדעת מתוכו מי ה-base ומי ה-extent (כיוון הגרירה). לכן עוקבים אחר היסטוריית
// הטקסט הנבחר: הצד שבו הבחירה גדלה/התכווצה הוא קצה ה-focus.
String? _rtlLastSel;
bool? _rtlReversed; // האם ה-focus גדל בקצה ה*סוף* של המחרוזת (offset גבוה).

/// הסקת כיוון הגרירה האחרון: true = ה-focus בקצה הסוף (offset גבוה),
/// false = ה-focus בקצה ההתחלה (offset נמוך), null = לא ידוע.
bool? get rtlInferredReversed => _rtlReversed;

/// מעדכן את ה-tracker לפי שינוי בחירה אמיתי (לא priming).
void trackRtlSelection(String? text) {
  if (rtlSelectionPriming) return;
  final t = text ?? '';
  final last = _rtlLastSel ?? '';
  if (t.isEmpty) {
    _rtlLastSel = '';
    _rtlReversed = null;
    return;
  }
  if (last.isEmpty || t == last) {
    _rtlLastSel = t;
    return;
  }
  if (t.length > last.length) {
    if (t.startsWith(last)) {
      _rtlReversed = true; // גדל בסוף
    } else if (t.endsWith(last)) {
      _rtlReversed = false; // גדל בהתחלה
    } else {
      _rtlReversed = null;
    }
  } else if (last.length > t.length) {
    if (last.startsWith(t)) {
      _rtlReversed = true; // התכווץ מהסוף → focus בסוף
    } else if (last.endsWith(t)) {
      _rtlReversed = false; // התכווץ מההתחלה → focus בהתחלה
    } else {
      _rtlReversed = null;
    }
  } else {
    _rtlReversed = null;
  }
  _rtlLastSel = t;
}

/// Intent ביניים: בקשת הרחבת בחירה לפי הכיוון ה*פיזי* של מקש החץ
/// (שמאל/ימין), לפני הכרעת הכיוון הלוגי (`forward`).
@immutable
class _PhysicalExtendSelectionIntent extends Intent {
  const _PhysicalExtendSelectionIntent({
    required this.physicalLeft,
    required this.word,
  });

  /// האם נלחץ חץ שמאל (אחרת — חץ ימין).
  final bool physicalLeft;

  /// האם זו הרחבה ברמת מילה (Ctrl/Alt+Shift+חץ) ולא ברמת תו.
  final bool word;
}

/// מתקן את כיוון מקשי Shift+חץ בבחירת טקסט RTL.
///
/// רקע: ב-`SelectableRegion` של Flutter מקשי החצים אינם מתחשבים בכיווניות
/// (flutter/flutter#78660 ואחרים). עוטפים ומיירטים Shift+חץ בלבד.
/// ב-LTR ה-widget שקוף.
class RtlSelectionShortcuts extends StatelessWidget {
  const RtlSelectionShortcuts({super.key, required this.child});

  final Widget child;

  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        _PhysicalExtendSelectionIntent(physicalLeft: true, word: false),
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        _PhysicalExtendSelectionIntent(physicalLeft: false, word: false),
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true, control: true):
        _PhysicalExtendSelectionIntent(physicalLeft: true, word: true),
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true, control: true):
        _PhysicalExtendSelectionIntent(physicalLeft: false, word: true),
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true, alt: true):
        _PhysicalExtendSelectionIntent(physicalLeft: true, word: true),
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true, alt: true):
        _PhysicalExtendSelectionIntent(physicalLeft: false, word: true),
  };

  @override
  Widget build(BuildContext context) {
    if (Directionality.maybeOf(context) != TextDirection.rtl) {
      return child;
    }
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PhysicalExtendSelectionIntent: _PhysicalExtendSelectionAction(),
        },
        child: child,
      ),
    );
  }
}

class _PhysicalExtendSelectionAction
    extends Action<_PhysicalExtendSelectionIntent> {
  @override
  Object? invoke(_PhysicalExtendSelectionIntent intent) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return null;
    }

    final inTextInput = _isTextInputContext(focusContext);

    // --- שדה קלט (EditableText/Quill) ---
    // ברמת תו Flutter כבר מהפך נכון לפי כיווניות → כיוון לוגי מקורי. ברמת
    // מילה Flutter אינו מהפך (באג) → מהפכים.
    if (inTextInput) {
      final forward = intent.word ? intent.physicalLeft : !intent.physicalLeft;
      return _dispatch(focusContext, word: intent.word, forward: forward);
    }

    final geo = _selectionGeometry(focusContext);
    if (geo == null) {
      // אין מידע על בחירה — היפוך פשוט.
      return _dispatch(focusContext,
          word: intent.word, forward: intent.physicalLeft);
    }

    // --- SelectableRegion: priming ---
    // צריך "לנעול" קודם את קצה ה-focus (extent), ואז להזיז אותו בכיוון הויזואלי.
    // הפריימוורק קובע isEnd = forward != isReversed, כאשר isReversed גאומטרי:
    // בשורה-אחת לפי X, ברב-שורתי לפי Y. כדי לנעול את ה-extent צריך
    // forward = !isReversed.
    //
    // [myReversed] = האם ה-focus בקצה הסוף של המחרוזת (offset גבוה).
    // הקשר ל-isReversed הגאומטרי: בשורה-אחת isReversed==myReversed; ברב-שורתי
    // isReversed==!myReversed (כי שם ההכרעה לפי Y).
    //
    // בשורה-אחת מעדיפים את הגאומטריה ה**מקומית** של האזור הנוכחי
    // (`geo.reversed`) — אמינה ולא מושפעת ממצב גלובלי של אזור אחר. רק
    // ברב-שורתי, שם `selectionEndpoints` ממיין לפי Y ומאבד את כיוון הגרירה,
    // נופלים ל-tracker הגלובלי (שמתאפס כשעוברים אזור, דרך trackRtlSelection).
    final bool myReversed;
    if (geo.multiLine) {
      myReversed = rtlInferredReversed ?? true;
    } else {
      myReversed = geo.reversed;
    }
    final frameworkReversed = geo.multiLine ? !myReversed : myReversed;
    final lockForward = !frameworkReversed;

    rtlSelectionPriming = true;
    _dispatch(focusContext, word: false, forward: lockForward); // נעילת extent
    _dispatch(focusContext, word: false, forward: !lockForward); // שחזור
    rtlSelectionPriming = false;
    return _dispatch(focusContext,
        word: intent.word, forward: intent.physicalLeft);
  }

  Object? _dispatch(BuildContext context,
      {required bool word, required bool forward}) {
    final Intent intent = word
        ? ExtendSelectionToNextWordBoundaryIntent(
            forward: forward, collapseSelection: false)
        : ExtendSelectionByCharacterIntent(
            forward: forward, collapseSelection: false);
    return Actions.maybeInvoke(context, intent);
  }

  /// גאומטריית הבחירה הנוכחית ב-[SelectableRegion] הממוקד, מתוך
  /// [SelectableRegionState.selectionEndpoints] (getter ציבורי המחזיר
  /// `[base, extent]` — ממוין רק לפי Y).
  ///
  /// - [multiLine]: הקצוות בגבהים שונים (הפרש Y משמעותי).
  /// - [reversed]: בשורה-אחת, האם ה-base נמצא ימינה מה-extent (גרירה "קדימה",
  ///   מהסוף להתחלה). נגזר מהשוואת X של שני הקצוות (שב-single-line נשמרים
  ///   בסדר base→extent). חסר משמעות ב-multiLine (ה-getter ממיין לפי Y).
  ///
  /// מחזיר null כשאין בחירה פעילה או שאי אפשר לקבוע.
  ({bool multiLine, bool reversed})? _selectionGeometry(
      BuildContext focusContext) {
    final state = focusContext.findAncestorStateOfType<SelectableRegionState>();
    if (state == null) return null;
    try {
      final points = state.selectionEndpoints;
      if (points.length < 2) return null;
      final base = points.first.point;
      final extent = points.last.point;
      if ((base.dy - extent.dy).abs() > 1.0) {
        return (multiLine: true, reversed: false);
      }
      return (multiLine: false, reversed: base.dx > extent.dx);
    } catch (_) {
      // selectionEndpoints זורק כשאין בחירה פעילה.
      return null;
    }
  }
}

bool _isTextInputContext(BuildContext context) {
  if (context.widget is EditableText) return true;
  var found = false;
  context.visitAncestorElements((element) {
    if (element.widget is EditableText) {
      found = true;
      return false;
    }
    final name = element.widget.runtimeType.toString();
    if (name.contains('RawEditor') || name.contains('QuillEditor')) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}
