import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

typedef PdfScrollBoundsBuilder = Rect? Function(PdfViewerController controller);

/// פס גלילה מותאם אישית ל-PDF עם track מלא.
class PdfScrollbar extends StatefulWidget {
  final PdfViewerController controller;
  final ScrollbarOrientation orientation;
  final double trackThickness;
  final Color? trackColor;
  final Color? thumbColor;
  final double thumbMinSize;
  final PdfScrollBoundsBuilder? scrollBoundsBuilder;
  final bool freezeThumb;

  const PdfScrollbar({
    super.key,
    required this.controller,
    required this.orientation,
    this.trackThickness = 12.0,
    this.trackColor,
    this.thumbColor,
    this.thumbMinSize = 40.0,
    this.scrollBoundsBuilder,
    this.freezeThumb = false,
  });

  @override
  State<PdfScrollbar> createState() => _PdfScrollbarState();
}

class _PdfScrollbarState extends State<PdfScrollbar> {
  final GlobalKey _trackKey = GlobalKey();
  double? _lastThumbTop;
  double? _lastThumbHeight;
  int? _lastPageNumber;
  double? _dragPointerOffsetWithinThumb;

  /// מיקום המחוון בזמן גרירה פעילה. כשהוא לא null, המחוון נצמד לאצבע
  /// במקום להיגזר מ-`controller.visibleRect`, כך שהוא חלק ולא ממתין לרינדור.
  double? _activeDragThumbTop;

  /// מספר העמוד בתוך המחוון. FittedBox מבטיח שורה אחת תמיד — מספרים
  /// תלת/ארבע-ספרתיים (100+, ש"ס) מתכווצים במקום להישבר לשתי שורות.
  Widget _buildPageNumberText(int pageNumber, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          pageNumber.toString(),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = widget.orientation == ScrollbarOrientation.right ||
        widget.orientation == ScrollbarOrientation.left;

    if (!isVertical || widget.scrollBoundsBuilder == null) {
      // PdfViewerScrollThumb זורק אם ה-controller לא מוכן עדיין (race condition ב-pdfrx).
      // חשוב: PdfViewerScrollThumb חייב להיות בתוך ה-builder, לא כ-child,
      // כדי שלא יבצע build() כשה-controller לא מוכן.
      return AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (!widget.controller.isReady) return const SizedBox.shrink();
          try {
            widget.controller.visibleRect;
          } catch (_) {
            return const SizedBox.shrink();
          }
          return PdfViewerScrollThumb(
            controller: widget.controller,
            orientation: widget.orientation,
            thumbSize: isVertical
                ? Size(widget.trackThickness, widget.thumbMinSize)
                : Size(widget.thumbMinSize, widget.trackThickness),
            thumbBuilder: (context, thumbSize, pageNumber, controller) {
              final colorScheme = Theme.of(context).colorScheme;
              return Container(
                width: isVertical ? widget.trackThickness : thumbSize.width,
                height: isVertical ? thumbSize.height : widget.trackThickness,
                decoration: BoxDecoration(
                  color: widget.thumbColor ??
                      colorScheme.outline.withValues(alpha: 0.75),
                  borderRadius:
                      BorderRadius.circular(widget.trackThickness / 2),
                ),
                child: isVertical
                    ? Center(
                        child:
                            _buildPageNumberText(pageNumber ?? 1, colorScheme),
                      )
                    : null,
              );
            },
          );
        },
      );
    }

    final alignment = widget.orientation == ScrollbarOrientation.left
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedTrackColor = widget.trackColor ??
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    final resolvedThumbColor =
        widget.thumbColor ?? colorScheme.primary.withValues(alpha: 0.82);

    // PdfViewerController.value זורק לפני שה-viewer מתחבר אליו.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        if (!widget.controller.isReady) {
          return const SizedBox.shrink();
        }

        final bounds = widget.scrollBoundsBuilder!(widget.controller);
        if (bounds == null) {
          return const SizedBox.shrink();
        }

        // controller.visibleRect זורק אם ה-PdfViewer state לא חובר עדיין
        final Rect visibleRect;
        try {
          visibleRect = widget.controller.visibleRect;
        } catch (_) {
          return const SizedBox.shrink();
        }
        final visibleHeight = math.min(visibleRect.height, bounds.height);
        final scrollableExtent = math.max(bounds.height - visibleHeight, 0.0);
        final currentTop = (visibleRect.top - bounds.top)
            .clamp(0.0, scrollableExtent)
            .toDouble();

        return Align(
          alignment: alignment,
          child: SizedBox(
            width: widget.trackThickness,
            height: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                if (trackHeight <= 0) {
                  return const SizedBox.shrink();
                }

                if (scrollableExtent == 0) {
                  return const SizedBox.shrink();
                }

                final rawThumbHeight = bounds.height <= 0
                    ? trackHeight
                    : trackHeight * (visibleHeight / bounds.height);
                final computedThumbHeight =
                    rawThumbHeight.clamp(widget.thumbMinSize, trackHeight);
                final pageNumber = widget.controller.pageNumber ?? 1;
                final useFrozenThumb =
                    widget.freezeThumb && _lastThumbTop != null;
                final thumbHeight =
                    useFrozenThumb ? _lastThumbHeight! : computedThumbHeight;
                final maxThumbTop = math.max(trackHeight - thumbHeight, 0.0);
                final computedThumbTop = scrollableExtent == 0
                    ? 0.0
                    : maxThumbTop * (currentTop / scrollableExtent);
                final bool isDragging =
                    !widget.freezeThumb && _activeDragThumbTop != null;
                final double thumbTop;
                if (isDragging) {
                  thumbTop =
                      _activeDragThumbTop!.clamp(0.0, maxThumbTop).toDouble();
                } else if (useFrozenThumb) {
                  thumbTop = _lastThumbTop!.clamp(0.0, maxThumbTop).toDouble();
                } else {
                  thumbTop = computedThumbTop;
                }
                final displayedPageNumber =
                    useFrozenThumb ? _lastPageNumber ?? pageNumber : pageNumber;

                if (!widget.freezeThumb || _lastThumbTop == null) {
                  _lastThumbTop = computedThumbTop;
                  _lastThumbHeight = computedThumbHeight;
                  _lastPageNumber = pageNumber;
                }

                // animate=false בזמן גרירה: מיקום מיידי (Duration.zero) במקום
                // אנימציית 200ms שמצטברת בכל drag update ויוצרת השהיה.
                void jumpToThumbTop(double desiredThumbTop,
                    {bool animate = true}) {
                  if (widget.freezeThumb) return;
                  if (maxThumbTop <= 0) return;
                  final normalizedTop =
                      (desiredThumbTop.clamp(0.0, maxThumbTop) / maxThumbTop)
                          .toDouble();
                  final targetTop =
                      bounds.top + normalizedTop * scrollableExtent;
                  final zoom = widget.controller.value.zoom;
                  final targetCenter = Offset(
                    visibleRect.center.dx,
                    targetTop + visibleHeight / 2,
                  );
                  widget.controller.goTo(
                    widget.controller.calcMatrixFor(
                      targetCenter,
                      zoom: zoom,
                      viewSize: widget.controller.viewSize,
                    ),
                    duration: animate
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                  );
                }

                void startThumbDrag(DragStartDetails details) {
                  if (widget.freezeThumb) return;
                  _dragPointerOffsetWithinThumb = details.localPosition.dy;
                  // נצמד מיד לאצבע מהמיקום הנוכחי של המחוון.
                  setState(() => _activeDragThumbTop = thumbTop);
                }

                void updateThumbDrag(DragUpdateDetails details) {
                  if (widget.freezeThumb) return;
                  final trackContext = _trackKey.currentContext;
                  if (trackContext == null) return;
                  final trackBox =
                      trackContext.findRenderObject() as RenderBox?;
                  if (trackBox == null) return;
                  final localPosition =
                      trackBox.globalToLocal(details.globalPosition);
                  final desiredThumbTop = localPosition.dy -
                      (_dragPointerOffsetWithinThumb ?? thumbHeight / 2);
                  // המחוון נצמד לאצבע מיד (חלק), והתצוגה מתעדכנת ברקע ללא אנימציה.
                  setState(() => _activeDragThumbTop =
                      desiredThumbTop.clamp(0.0, maxThumbTop).toDouble());
                  jumpToThumbTop(desiredThumbTop, animate: false);
                }

                void endThumbDrag() {
                  _dragPointerOffsetWithinThumb = null;
                  if (_activeDragThumbTop != null) {
                    setState(() => _activeDragThumbTop = null);
                  }
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final tapY = details.localPosition.dy;
                    final isTapOnThumb =
                        tapY >= thumbTop && tapY <= thumbTop + thumbHeight;
                    if (isTapOnThumb) return;
                    jumpToThumbTop(details.localPosition.dy - thumbHeight / 2);
                  },
                  child: Stack(
                    children: [
                      Container(
                        key: _trackKey,
                        width: widget.trackThickness,
                        decoration: BoxDecoration(
                          color: resolvedTrackColor,
                          borderRadius:
                              BorderRadius.circular(widget.trackThickness / 2),
                        ),
                      ),
                      Positioned(
                        top: thumbTop,
                        left: 0,
                        right: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: startThumbDrag,
                          onVerticalDragUpdate: updateThumbDrag,
                          onVerticalDragEnd: (_) => endThumbDrag(),
                          onVerticalDragCancel: endThumbDrag,
                          child: Container(
                            width: widget.trackThickness,
                            height: thumbHeight,
                            decoration: BoxDecoration(
                              color: resolvedThumbColor,
                              borderRadius: BorderRadius.circular(
                                  widget.trackThickness / 2),
                            ),
                            child: Center(
                              child: _buildPageNumberText(
                                  displayedPageNumber, colorScheme),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// פס גלילה אופקי מותאם — ללא שימוש ב-PdfViewerScrollThumb כדי למנוע
/// את ה-race condition של visibleRect בתוך build() של pdfrx.
class PdfHorizontalScrollbar extends StatefulWidget {
  final PdfViewerController controller;
  final double trackThickness;
  final Color? trackColor;
  final Color? thumbColor;
  static const double _minThumbWidth = 60.0;

  const PdfHorizontalScrollbar({
    super.key,
    required this.controller,
    this.trackThickness = 8.0,
    this.trackColor,
    this.thumbColor,
  });

  @override
  State<PdfHorizontalScrollbar> createState() => _PdfHorizontalScrollbarState();
}

class _PdfHorizontalScrollbarState extends State<PdfHorizontalScrollbar> {
  double? _dragPointerOffsetWithinThumb;
  final GlobalKey _trackKey = GlobalKey();

  /// מיקום המחוון בזמן גרירה פעילה (ראה הסבר בפס האנכי).
  double? _activeDragThumbLeft;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedThumbColor =
        widget.thumbColor ?? colorScheme.outline.withValues(alpha: 0.75);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isReady) return const SizedBox.shrink();

        final Rect visibleRect;
        final Size documentSize;
        try {
          visibleRect = widget.controller.visibleRect;
          documentSize = widget.controller.layout.documentSize;
        } catch (_) {
          return const SizedBox.shrink();
        }

        final totalWidth = documentSize.width;
        if (totalWidth <= 0) return const SizedBox.shrink();

        return LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            if (trackWidth <= 0) return const SizedBox.shrink();

            final visibleWidth = visibleRect.width.clamp(0.0, totalWidth);
            final scrollableExtent = math.max(totalWidth - visibleWidth, 0.0);
            if (scrollableExtent == 0) return const SizedBox.shrink();

            final thumbWidthRaw = totalWidth <= 0
                ? trackWidth
                : trackWidth * (visibleWidth / totalWidth);
            final thumbWidth = thumbWidthRaw.clamp(
                PdfHorizontalScrollbar._minThumbWidth, trackWidth);
            final maxThumbLeft = math.max(trackWidth - thumbWidth, 0.0);
            final currentLeft = (visibleRect.left).clamp(0.0, scrollableExtent);
            final computedThumbLeft =
                maxThumbLeft * (currentLeft / scrollableExtent);
            final thumbLeft = _activeDragThumbLeft != null
                ? _activeDragThumbLeft!.clamp(0.0, maxThumbLeft).toDouble()
                : computedThumbLeft;

            // animate=false בזמן גרירה: מיקום מיידי במקום אנימציית 200ms.
            void jumpToThumbLeft(double desiredThumbLeft,
                {bool animate = true}) {
              if (maxThumbLeft <= 0) return;
              final normalized =
                  (desiredThumbLeft.clamp(0.0, maxThumbLeft) / maxThumbLeft)
                      .toDouble();
              final targetLeft = normalized * scrollableExtent;
              final zoom = widget.controller.value.zoom;
              final targetCenter = Offset(
                targetLeft + visibleWidth / 2,
                visibleRect.center.dy,
              );
              widget.controller.goTo(
                widget.controller.calcMatrixFor(
                  targetCenter,
                  zoom: zoom,
                  viewSize: widget.controller.viewSize,
                ),
                duration:
                    animate ? const Duration(milliseconds: 200) : Duration.zero,
              );
            }

            void startDrag(DragStartDetails details) {
              _dragPointerOffsetWithinThumb = details.localPosition.dx;
              setState(() => _activeDragThumbLeft = thumbLeft);
            }

            void updateDrag(DragUpdateDetails details) {
              final trackCtx = _trackKey.currentContext;
              if (trackCtx == null) return;
              final trackBox = trackCtx.findRenderObject() as RenderBox?;
              if (trackBox == null) return;
              final local = trackBox.globalToLocal(details.globalPosition);
              final desiredThumbLeft =
                  local.dx - (_dragPointerOffsetWithinThumb ?? thumbWidth / 2);
              setState(() => _activeDragThumbLeft =
                  desiredThumbLeft.clamp(0.0, maxThumbLeft).toDouble());
              jumpToThumbLeft(desiredThumbLeft, animate: false);
            }

            void endDrag() {
              _dragPointerOffsetWithinThumb = null;
              if (_activeDragThumbLeft != null) {
                setState(() => _activeDragThumbLeft = null);
              }
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final tapX = details.localPosition.dx;
                if (tapX >= thumbLeft && tapX <= thumbLeft + thumbWidth) {
                  return;
                }
                jumpToThumbLeft(details.localPosition.dx - thumbWidth / 2);
              },
              child: SizedBox(
                height: widget.trackThickness,
                child: Stack(
                  children: [
                    Container(
                      key: _trackKey,
                      height: widget.trackThickness,
                    ),
                    Positioned(
                      left: thumbLeft,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: startDrag,
                        onHorizontalDragUpdate: updateDrag,
                        onHorizontalDragEnd: (_) => endDrag(),
                        onHorizontalDragCancel: endDrag,
                        child: Container(
                          width: thumbWidth,
                          height: widget.trackThickness,
                          decoration: BoxDecoration(
                            color: resolvedThumbColor,
                            borderRadius: BorderRadius.circular(
                                widget.trackThickness / 2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
