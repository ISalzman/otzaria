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
import 'package:otzaria/widgets/layout/floating_panel.dart';

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

  const ContextOverlayPanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.child,
    this.width = 400,
    this.alignment =
        AlignmentDirectional.centerEnd, // ברירת מחדל: שמאל בעברית (RTL)
    this.backgroundColor,
    this.contentPadding = const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
    this.deferChildBuildOnOpen = false,
    this.preserveChildStateOnClose = false,
  });

  @override
  State<ContextOverlayPanel> createState() => _ContextOverlayPanelState();
}

class _ContextOverlayPanelState extends State<ContextOverlayPanel> {
  static const _opacityDuration = Duration(milliseconds: 200);
  static const _slideDuration = Duration(milliseconds: 300);

  Timer? _disposeChildTimer;
  bool _isDeferredBuildScheduled = false;
  late bool _shouldBuildChild;

  @override
  void initState() {
    super.initState();
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
    _disposeChildTimer = Timer(_slideDuration, () {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveBackgroundColor =
        widget.backgroundColor ?? cs.surfaceContainerHigh;
    // centerEnd = שמאל פיזי ב-RTL, centerStart = ימין פיזי
    final isLeft = widget.alignment == AlignmentDirectional.centerEnd;

    return IgnorePointer(
      ignoring: !widget.isOpen,
      child: Stack(
        children: [
          // ── scrim (רקע שקוף לחיץ) ──────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: AnimatedOpacity(
                duration: _opacityDuration,
                opacity: widget.isOpen ? 1.0 : 0.0,
                child: ColoredBox(
                  color: cs.scrim.withValues(alpha: 0.30),
                ),
              ),
            ),
          ),
          // ── הפאנל: צף עם פינות מעוגלות ושוליים מהצדדים ────────────────
          Positioned(
            top: 10,
            bottom: 12,
            left: isLeft ? 10 : null,
            right: isLeft ? null : 10,
            child: AnimatedOpacity(
              duration: _opacityDuration,
              opacity: widget.isOpen ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: _slideDuration,
                curve: Curves.easeInOut,
                offset: widget.isOpen
                    ? Offset.zero
                    : (isLeft
                        ? const Offset(-1, 0) // שמאל → יוצא שמאלה
                        : const Offset(1, 0)), // ימין → יוצא ימינה
                child: FloatingPanel(
                  elevation: 8,
                  color: effectiveBackgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: widget.width,
                    child: SafeArea(
                      child: Padding(
                        padding: widget.contentPadding,
                        child: _shouldBuildChild
                            ? widget.child
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
