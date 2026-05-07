import 'package:flutter/material.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/layout/floating_panel.dart';
import 'package:otzaria/widgets/layout/resizable_drag_handle.dart';

/// חלונית צד אדפטיבית:
/// במסך רחב דוחקת תוכן, ובמסך צר נפתחת כ-overlay.
///
/// כללי ברירת מחדל:
/// - תוכן החלונית מקבל שכבת רקע נוספת של חלון (solidPanelBackground).
/// - מעבר מרוחב רחב למסך צר סוגר אוטומטית את החלונית.
/// - חלונית ניווט אמורה להיות בצד ימין (`centerEnd`) וחלונית מידע בצד שמאל (`centerStart`).
class AdaptiveSidePane extends StatefulWidget {
  final bool isOpen;
  final Widget mainContent;
  final Widget paneContent;
  final double paneWidth;
  final double minMainContentWidth;
  final VoidCallback onClose;
  final VoidCallback? onOpen;
  final Color? paneColor;
  final AlignmentDirectional alignment;
  final bool wrapPaneInFloatingPanel;
  final bool isResizable;
  final double minPaneWidth;
  final double? maxPaneWidth;
  final ValueChanged<double>? onPaneWidthChanged;
  final VoidCallback? onPaneResizeEnd;
  final Widget Function(
          BuildContext context, Widget paneContent, double paneWidth)?
      widePaneBuilder;
  final Widget Function(BuildContext context, Widget paneContent)?
      narrowPaneBuilder;
  final bool autoHandleResponsiveVisibility;

  const AdaptiveSidePane({
    super.key,
    required this.isOpen,
    required this.mainContent,
    required this.paneContent,
    this.paneWidth = 340,
    this.minMainContentWidth = 500,
    required this.onClose,
    this.onOpen,
    this.paneColor,
    this.alignment = AlignmentDirectional.centerEnd,
    this.wrapPaneInFloatingPanel = true,
    this.isResizable = false,
    this.minPaneWidth = 220,
    this.maxPaneWidth,
    this.onPaneWidthChanged,
    this.onPaneResizeEnd,
    this.widePaneBuilder,
    this.narrowPaneBuilder,
    this.autoHandleResponsiveVisibility = true,
  });

  @override
  State<AdaptiveSidePane> createState() => _AdaptiveSidePaneState();
}

class _AdaptiveSidePaneState extends State<AdaptiveSidePane> {
  bool? _lastHadRoomForSideBySide;
  bool _isResizing = false;
  static const BorderRadius _kPanelRadius =
      BorderRadius.all(Radius.circular(AppTokens.radiusPanel));
  static const double _kWideTopGap = 14;
  static const double _kWideBottomGap = 10;
  static const double _kWideOuterSideGap = 10;
  static const double _kWideInnerSideGap = 12;
  static const double _kNarrowTopGap = 14;
  static const double _kNarrowBottomGap = 10;
  Color _effectivePaneColor(BuildContext context) {
    return widget.paneColor ?? AppSurfaces.solidPanelBackground(context);
  }

  bool _isPaneOnRight(BuildContext context) {
    if (widget.alignment == AlignmentDirectional.centerEnd) {
      return true;
    }
    if (widget.alignment == AlignmentDirectional.centerStart) {
      return false;
    }

    final resolved = widget.alignment.resolve(Directionality.of(context));
    return resolved.x >= 0;
  }

  void _handleResponsiveAutoClose(bool hasRoomForSideBySide) {
    final previous = _lastHadRoomForSideBySide;
    _lastHadRoomForSideBySide = hasRoomForSideBySide;

    if (previous == true && !hasRoomForSideBySide && widget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isOpen) {
          widget.onClose();
        }
      });
    }

    if (previous == false &&
        hasRoomForSideBySide &&
        !widget.isOpen &&
        widget.onOpen != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.isOpen) {
          widget.onOpen!.call();
        }
      });
    }
  }

  Widget _buildPaneShell(
    BuildContext context,
    Widget child, {
    required bool paneOnRight,
  }) {
    final paneColor = _effectivePaneColor(context);
    final shadowColor =
        Theme.of(context).colorScheme.shadow.withValues(alpha: 0.22);

    if (widget.wrapPaneInFloatingPanel) {
      return FloatingPanel(
        color: paneColor,
        elevation: 8,
        shadowColor: shadowColor,
        borderRadius: _kPanelRadius,
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: _kPanelRadius,
      child: Material(
        color: paneColor,
        elevation: 4,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        borderRadius: _kPanelRadius,
        child: child,
      ),
    );
  }

  Widget _buildResizeHandle(bool paneOnRight) {
    return ResizableDragHandle(
      isVertical: true,
      showDivider: false,
      onDragStart: () {
        if (_isResizing) return;
        setState(() => _isResizing = true);
      },
      onDragDelta: (delta) {
        final effectiveDelta = paneOnRight ? -delta : delta;
        final nextWidth = (widget.paneWidth + effectiveDelta).clamp(
          widget.minPaneWidth,
          widget.maxPaneWidth ?? double.infinity,
        );
        widget.onPaneWidthChanged?.call(nextWidth.toDouble());
      },
      onDragEnd: () {
        if (_isResizing) {
          setState(() => _isResizing = false);
        }
        widget.onPaneResizeEnd?.call();
      },
    );
  }

  Widget _buildNarrowPane(BuildContext context, Widget child) {
    return _buildPaneShell(
      context,
      widget.wrapPaneInFloatingPanel
          ? child
          : Material(
              color: _effectivePaneColor(context),
              child: child,
            ),
      paneOnRight: _isPaneOnRight(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final paneOnRight = _isPaneOnRight(context);
        final wideOccupiedWidth =
            widget.paneWidth + _kWideOuterSideGap + _kWideInnerSideGap;
        final calculatedHasRoomForSideBySide = constraints.maxWidth >=
            (wideOccupiedWidth + widget.minMainContentWidth);
        final hasRoomForSideBySide = _isResizing
            ? (_lastHadRoomForSideBySide ?? calculatedHasRoomForSideBySide)
            : calculatedHasRoomForSideBySide;

        if (widget.autoHandleResponsiveVisibility && !_isResizing) {
          _handleResponsiveAutoClose(hasRoomForSideBySide);
        }

        if (hasRoomForSideBySide) {
          final widePaneContent = widget.widePaneBuilder != null
              ? widget.widePaneBuilder!(
                  context, widget.paneContent, widget.paneWidth)
              : widget.paneContent;

          final widePane = SizedBox(
            width: widget.paneWidth,
            child: _buildPaneShell(
              context,
              widePaneContent,
              paneOnRight: paneOnRight,
            ),
          );

          final showHandle = widget.isOpen &&
              widget.isResizable &&
              widget.onPaneWidthChanged != null;
          final overhang = showHandle ? handleHitOverhang(context) : 0.0;

          final paneSlot = Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration:
                    _isResizing ? Duration.zero : AppTokens.animPanelSlide,
                curve: Curves.easeInOut,
                width: widget.isOpen ? wideOccupiedWidth : 0,
                child: ClipRect(
                  child: Align(
                    alignment: paneOnRight
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: OverflowBox(
                      maxWidth: wideOccupiedWidth,
                      minWidth: 0,
                      alignment: paneOnRight
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          top: _kWideTopGap,
                          bottom: _kWideBottomGap,
                          start: paneOnRight
                              ? _kWideInnerSideGap
                              : _kWideOuterSideGap,
                          end: paneOnRight
                              ? _kWideOuterSideGap
                              : _kWideInnerSideGap,
                        ),
                        child: SizedBox(
                          width: widget.paneWidth,
                          child: widePane,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showHandle)
                Positioned(
                  top: _kWideTopGap,
                  bottom: _kWideBottomGap,
                  // במצב רחב הוו מיושר לגבול הפאנל עצמו, לא לגבול ה-slot.
                  left: paneOnRight ? _kWideOuterSideGap - overhang : null,
                  right: paneOnRight ? null : _kWideOuterSideGap - overhang,
                  child: _buildResizeHandle(paneOnRight),
                ),
            ],
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: paneOnRight
                ? [paneSlot, Expanded(child: widget.mainContent)]
                : [Expanded(child: widget.mainContent), paneSlot],
          );
        }

        final narrowPaneContent = widget.narrowPaneBuilder != null
            ? widget.narrowPaneBuilder!(context, widget.paneContent)
            : _buildNarrowPane(context, SafeArea(child: widget.paneContent));
        final narrowPane = widget.narrowPaneBuilder != null
            ? _buildPaneShell(
                context,
                narrowPaneContent,
                paneOnRight: paneOnRight,
              )
            : narrowPaneContent;

        final showHandle = widget.isResizable &&
            widget.onPaneWidthChanged != null;
        final closedOffset =
            paneOnRight ? const Offset(1, 0) : const Offset(-1, 0);

        return Stack(
          children: [
            Positioned.fill(child: widget.mainContent),
            IgnorePointer(
              ignoring: !widget.isOpen,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: AnimatedOpacity(
                        duration: AppTokens.animPanelOpacity,
                        opacity: widget.isOpen ? 1.0 : 0.0,
                        child: ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .scrim
                              .withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: _kNarrowTopGap,
                    bottom: _kNarrowBottomGap,
                    right: paneOnRight ? 0 : null,
                    left: paneOnRight ? null : 0,
                    width: widget.paneWidth,
                    child: AnimatedOpacity(
                      duration: AppTokens.animPanelOpacity,
                      opacity: widget.isOpen ? 1.0 : 0.0,
                      child: AnimatedSlide(
                        duration: AppTokens.animPanelSlide,
                        curve: Curves.easeInOut,
                        offset: widget.isOpen ? Offset.zero : closedOffset,
                        child: narrowPane,
                      ),
                    ),
                  ),
                  if (showHandle)
                    Positioned(
                      top: _kNarrowTopGap,
                      bottom: _kNarrowBottomGap,
                      right: paneOnRight
                          ? widget.paneWidth - handleHitOverhang(context)
                          : null,
                      left: paneOnRight
                          ? null
                          : widget.paneWidth - handleHitOverhang(context),
                      child: AnimatedOpacity(
                        duration: AppTokens.animPanelOpacity,
                        opacity: widget.isOpen ? 1.0 : 0.0,
                        child: AnimatedSlide(
                          duration: AppTokens.animPanelSlide,
                          curve: Curves.easeInOut,
                          offset: widget.isOpen ? Offset.zero : closedOffset,
                          child: _buildResizeHandle(paneOnRight),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
