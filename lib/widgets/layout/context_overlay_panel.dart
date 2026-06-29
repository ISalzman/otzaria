// lib/widgets/context_overlay_panel.dart
//
// ContextOverlayPanel — פאנל הגדרות overlay שצף מעל התוכן
//
// רכיב behavior/layout שמשתמש ב-FloatingPanel כמעטפת עיצובית.
// מטרתו לאחד את ההתנהגות של פאנלי הגדרות בלוח שנה, ספריה, וגימטריה.
//
// **מאפיינים:**
// • פתיחה וסגירה באנימציית slide מהצד
// • scrim לחיץ לסגירה
// • גובה מלא של אזור התוכן
// • צבע רקע לפי AppTopBar (surfaceContainerHigh)
// • תמיכה בימין/שמאל
//
// **שימוש:**
// ```dart
// Stack(
//   children: [
//     MainContent(),
//     ContextOverlayPanel(
//       isOpen: isSettingsPanelOpen,
//       onClose: () => setState(() => isSettingsPanelOpen = false),
//       child: MySettingsContent(),
//     ),
//   ],
// )
// ```

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/layout/floating_panel.dart';
import 'package:otzaria/widgets/layout/panel_scrollable_content.dart';
import 'package:otzaria/widgets/layout/resizable_drag_handle.dart';

class ContextOverlayPanel extends StatefulWidget {
  /// האם הפאנל פתוח
  final bool isOpen;

  /// callback לסגירת הפאנל
  final VoidCallback onClose;

  /// תוכן הפאנל
  final Widget child;

  /// רוחב הפאנל (ברירת מחדל: 400)
  final double width;

  /// יישור הפאנל (ברירת מחדל: start - ימין בעברית)
  final AlignmentDirectional alignment;

  /// צבע רקע (ברירת מחדל: surfaceContainerHigh)
  final Color? backgroundColor;

  /// ריפוד פנימי אחיד לתוכן הפאנל
  final EdgeInsetsGeometry contentPadding;

  /// האם לדחות את בניית התוכן לפריים שאחרי פתיחת הפאנל.
  ///
  /// שימושי כאשר התוכן כבד, ורוצים שהמעטפת והאנימציה יופיעו מיד
  /// בלי לחכות לסיום build/layout של כל התוכן.
  final bool deferChildBuildOnOpen;

  /// האם לשמור את התוכן חי גם אחרי סגירת הפאנל.
  ///
  /// כאשר `true`, עלות הבנייה משולמת רק בפתיחה הראשונה.
  final bool preserveChildStateOnClose;

  /// רוחב מינימלי לגרירה
  final double minWidth;

  /// רוחב מקסימלי לגרירה
  final double? maxWidth;

  /// כותרת אופציונלית שתוצג בראש הפאנל (headlineMedium, מודגש)
  ///
  /// כשמוגדרת עם [scrollable]=false, `child` צריך להיות `Expanded(...)`.
  /// כשמוגדרת עם [scrollable]=true, `child` הוא ה-content ישירות.
  final String? title;

  /// האם לעטוף את [child] ב-[PanelScrollableContent] אוטומטית.
  ///
  /// כש-true: ה-Scrollbar יושב בתוך [contentPadding] הקיים (ללא תוספת),
  /// והתוכן מקבל את ה-padding האופקי מבפנים.
  /// כש-false (ברירת מחדל): ה-child אחראי לניהול הגלילה שלו.
  final bool scrollable;

  const ContextOverlayPanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.child,
    this.width = 400,
    this.alignment = AlignmentDirectional.centerEnd,
    this.backgroundColor,
    this.contentPadding = const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
    this.deferChildBuildOnOpen = false,
    this.preserveChildStateOnClose = false,
    this.minWidth = 200,
    this.maxWidth,
    this.title,
    this.scrollable = false,
  });

  @override
  State<ContextOverlayPanel> createState() => _ContextOverlayPanelState();
}

class _ContextOverlayPanelState extends State<ContextOverlayPanel> {
  Timer? _disposeChildTimer;
  bool _isDeferredBuildScheduled = false;
  late bool _shouldBuildChild;
  late double _currentWidth;

  @override
  void initState() {
    super.initState();
    _currentWidth = widget.width;
    _shouldBuildChild = widget.isOpen && !widget.deferChildBuildOnOpen;
    if (widget.isOpen && widget.deferChildBuildOnOpen) {
      _scheduleDeferredChildBuild();
    }
  }

  @override
  void didUpdateWidget(covariant ContextOverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isOpen) {
      _disposeChildTimer?.cancel();
      if (_shouldBuildChild) {
        return;
      }
      if (widget.deferChildBuildOnOpen) {
        _scheduleDeferredChildBuild();
      } else {
        setState(() {
          _shouldBuildChild = true;
        });
      }
      return;
    }

    if (widget.preserveChildStateOnClose) {
      return;
    }

    if (!oldWidget.isOpen || !_shouldBuildChild) {
      return;
    }

    _disposeChildTimer?.cancel();
    _disposeChildTimer = Timer(AppTokens.animPanelSlide, () {
      if (!mounted || widget.isOpen) {
        return;
      }
      setState(() {
        _shouldBuildChild = false;
      });
    });
  }

  @override
  void dispose() {
    _disposeChildTimer?.cancel();
    super.dispose();
  }

  void _scheduleDeferredChildBuild() {
    if (_shouldBuildChild || _isDeferredBuildScheduled) {
      return;
    }

    _isDeferredBuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isDeferredBuildScheduled = false;
      if (!mounted || !widget.isOpen || _shouldBuildChild) {
        return;
      }
      setState(() {
        _shouldBuildChild = true;
      });
    });
  }

  Widget _buildChildWithTitle(BuildContext context, EdgeInsets horizontal) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: horizontal.left,
            right: horizontal.right,
            bottom: 8,
          ),
          child: Center(
            child: Text(
              widget.title!,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }

  /// בונה את אזור התוכן עם [PanelScrollableContent].
  /// ה-padding האנכי נשאר בחוץ; האופקי עובר לתוך ה-ScrollView.
  Widget _buildScrollableContent(BuildContext context) {
    final resolved = widget.contentPadding.resolve(Directionality.of(context));
    final verticalPadding =
        EdgeInsets.only(top: resolved.top, bottom: resolved.bottom);
    final horizontalPadding =
        EdgeInsets.only(left: resolved.left, right: resolved.right);

    final scrollableChild = PanelScrollableContent(
      padding: horizontalPadding,
      child: widget.child,
    );

    return Padding(
      padding: verticalPadding,
      child: widget.title != null
          ? Column(
              children: [
                // כותרת בלבד (ה-child עצמו יופיע בתוך PanelScrollableContent)
                Padding(
                  padding: EdgeInsets.only(
                    left: horizontalPadding.left,
                    right: horizontalPadding.right,
                    bottom: 8,
                  ),
                  child: Center(
                    child: Text(
                      widget.title!,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(child: scrollableChild),
              ],
            )
          : scrollableChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveBackgroundColor =
        widget.backgroundColor ?? cs.surfaceContainerHigh;
    // centerEnd = שמאל פיזי ב-RTL, centerStart = ימין פיזי
    final isLeft = widget.alignment == AlignmentDirectional.centerEnd;
    final showHandle = widget.isOpen;
    final overhang = showHandle ? handleHitOverhang(context) : 0.0;

    return IgnorePointer(
      ignoring: !widget.isOpen,
      child: Stack(
        children: [
          // ── scrim ──────────────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: AnimatedOpacity(
                duration: AppTokens.animPanelOpacity,
                opacity: widget.isOpen ? 1.0 : 0.0,
                child: ColoredBox(
                  color: cs.scrim.withValues(alpha: 0.30),
                ),
              ),
            ),
          ),
          // ── הפאנל ──────────────────────────────────────────────────────
          Positioned(
            top: 10,
            bottom: 12,
            left: isLeft ? 10 : null,
            right: isLeft ? null : 10,
            child: AnimatedOpacity(
              duration: AppTokens.animPanelOpacity,
              opacity: widget.isOpen ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: AppTokens.animPanelSlide,
                curve: Curves.easeInOut,
                offset: widget.isOpen
                    ? Offset.zero
                    : (isLeft ? const Offset(-1, 0) : const Offset(1, 0)),
                child: FloatingPanel(
                  elevation: 8,
                  color: effectiveBackgroundColor,
                  child: SizedBox(
                    width: _currentWidth,
                    child: SafeArea(
                      child: widget.scrollable
                          ? (_shouldBuildChild
                              ? _buildScrollableContent(context)
                              : const SizedBox.shrink())
                          : Padding(
                              padding: widget.contentPadding,
                              child: _shouldBuildChild
                                  ? (widget.title != null
                                      ? _buildChildWithTitle(
                                          context, EdgeInsets.zero)
                                      : widget.child)
                                  : const SizedBox.shrink(),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── הוו גרירה (מעל ה-scrim) ────────────────────────────────────
          if (showHandle)
            Positioned(
              top: 10,
              bottom: 12,
              left: isLeft ? 10 + _currentWidth - overhang : null,
              right: isLeft ? null : 10 + _currentWidth - overhang,
              child: ResizableDragHandle(
                isVertical: true,
                showDivider: false,
                onDragDelta: (delta) {
                  final d = isLeft ? delta : -delta;
                  setState(() {
                    _currentWidth = (_currentWidth + d).clamp(
                        widget.minWidth, widget.maxWidth ?? double.infinity);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}
