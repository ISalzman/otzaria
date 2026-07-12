import 'dart:async';

import 'package:flutter/material.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/theme/app_tokens.dart';
import 'package:otzaria/widgets/misc/link_context_menu_entry.dart';

/// חלונית צפה עם תצוגה מקדימה של מפרש, שנפתחת בריחוף או בלחיצה על עוגן-מילה.
///
/// ממוקמת ליד נקודת הריחוף/הלחיצה, מוגבלת ברוחב ובגובה (4 שורות), נסגרת כשהסמן
/// עוזב אותה או בהקשה מחוצה לה — ונשארת פתוחה כשהסמן נכנס לתוכה (לסימון
/// והעתקה). לחיצה על הכותרת פותחת את היעד. מוצגת חלונית אחת בכל רגע.
class LinkPreviewOverlay {
  LinkPreviewOverlay._();

  static OverlayEntry? _entry;
  static VoidCallback? _onDismissed;
  static _LinkPreviewPanelState? _activePanel;

  /// מקפיצה תצוגה מקדימה של [link] ליד [globalPosition]. סוגרת חלונית קודמת.
  /// [onDismissed] נקרא כשהחלונית נסגרת (גם בהחלפה בחלונית אחרת).
  /// [onOpen] — לחיצה על כותרת החלונית (פתיחת היעד); הסגירה באחריות הקורא.
  /// [hoverMode] — חלונית שנפתחה מריחוף: בלי מחסום-הקשות מאחוריה (שלא תחסום
  /// את הלחיצה הבאה), והסגירה מתוזמנת דרך [scheduleHide] כשהסמן עוזב את העוגן.
  static void show(
    BuildContext context, {
    required Link link,
    required Offset globalPosition,
    VoidCallback? onDismissed,
    VoidCallback? onOpen,
    bool hoverMode = false,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    dismiss();
    _onDismissed = onDismissed;
    _entry = OverlayEntry(
      builder: (_) => _LinkPreviewPanel(
        link: link,
        anchorPosition: globalPosition,
        onDismiss: dismiss,
        onOpen: onOpen,
        hoverMode: hoverMode,
      ),
    );
    overlay.insert(_entry!);
  }

  /// מתזמנת סגירה קרובה (הסמן עזב את העוגן). כניסת הסמן לחלונית מבטלת אותה.
  static void scheduleHide() => _activePanel?._scheduleHide();

  /// מבטלת סגירה מתוזמנת (הסמן חזר לעוגן בזמן שהחלונית פתוחה).
  static void cancelScheduledHide() => _activePanel?._cancelHide();

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    final onDismissed = _onDismissed;
    _onDismissed = null;
    onDismissed?.call();
  }
}

class _LinkPreviewPanel extends StatefulWidget {
  final Link link;
  final Offset anchorPosition;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;
  final bool hoverMode;

  const _LinkPreviewPanel({
    required this.link,
    required this.anchorPosition,
    required this.onDismiss,
    this.onOpen,
    this.hoverMode = false,
  });

  @override
  State<_LinkPreviewPanel> createState() => _LinkPreviewPanelState();
}

class _LinkPreviewPanelState extends State<_LinkPreviewPanel> {
  static const double _maxWidth = 420;
  static const double _screenPadding = 8;
  static const double _anchorGap = 10;
  static const Duration _hideDelay = Duration(milliseconds: 250);

  final GlobalKey _panelKey = GlobalKey();
  Offset _offset = const Offset(_screenPadding, _screenPadding);
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    LinkPreviewOverlay._activePanel = this;
    // מיקום דו-שלבי: בנייה סמויה למדידת הגודל, ואז הצמדה לנקודת הלחיצה.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reposition());
  }

  @override
  void dispose() {
    if (identical(LinkPreviewOverlay._activePanel, this)) {
      LinkPreviewOverlay._activePanel = null;
    }
    _hideTimer?.cancel();
    super.dispose();
  }

  void _cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, widget.onDismiss);
  }

  void _reposition() {
    final panelBox = _panelKey.currentContext?.findRenderObject();
    final overlayBox =
        Overlay.maybeOf(context, rootOverlay: true)?.context.findRenderObject();
    if (panelBox is! RenderBox ||
        !panelBox.hasSize ||
        overlayBox is! RenderBox ||
        !overlayBox.hasSize) {
      return;
    }
    final panelSize = panelBox.size;
    final overlaySize = overlayBox.size;
    final anchor = overlayBox.globalToLocal(widget.anchorPosition);

    // אנכית: מתחת לנקודה, ואם אין מקום — מעליה.
    double top = anchor.dy + _anchorGap;
    if (top + panelSize.height > overlaySize.height - _screenPadding) {
      top = anchor.dy - _anchorGap - panelSize.height;
    }
    top = top.clamp(
      _screenPadding,
      (overlaySize.height - panelSize.height - _screenPadding)
          .clamp(_screenPadding, double.infinity),
    );

    // אופקית (RTL): הצמדת קצה ימני לנקודה, ואז חיתוך לגבולות המסך.
    double left = anchor.dx - panelSize.width;
    left = left.clamp(
      _screenPadding,
      (overlaySize.width - panelSize.width - _screenPadding)
          .clamp(_screenPadding, double.infinity),
    );

    setState(() {
      _offset = Offset(left, top);
      _visible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = (MediaQuery.of(context).size.width - _screenPadding * 2)
        .clamp(0.0, _maxWidth)
        .toDouble();
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // מחסום שקוף — הקשה מחוץ לחלונית סוגרת (גם במגע, שאין בו onExit).
        // בריחוף אין מחסום: הוא היה בולע את הלחיצה הבאה; הסגירה נעשית ביציאת
        // הסמן מהעוגן/מהחלונית (scheduleHide).
        if (!widget.hoverMode)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
            ),
          ),
        Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: Opacity(
            opacity: _visible ? 1 : 0,
            child: MouseRegion(
              onEnter: (_) => _cancelHide(),
              onExit: (_) => _scheduleHide(),
              // התוכן נטען אסינכרונית (FutureBuilder); כשהוא מגיע החלונית גדלה
              // אחרי המדידה הראשונית ועלולה לחרוג מהמסך — שינוי גודל מפעיל
              // מיקום מחדש (בסוף הפריים, כי עדכון overlay אסור בזמן layout).
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _reposition();
                  });
                  return true;
                },
                child: SizeChangedLayoutNotifier(
                  child: Material(
                    key: _panelKey,
                    elevation: 8,
                    color: colorScheme.surface,
                    borderRadius: AppTokens.borderRadiusAll,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: SelectionArea(
                          child: LinkHoverPreviewContent(
                            link: widget.link,
                            maxContentLines: 4,
                            compact: true,
                            onOpen: widget.onOpen,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
