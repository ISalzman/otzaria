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
  double? _lastThumbTop;
  double? _lastThumbHeight;
  int? _lastPageNumber;

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
                        child: Text(
                          (pageNumber ?? 1).toString(),
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                final thumbTop = useFrozenThumb
                    ? _lastThumbTop!.clamp(0.0, maxThumbTop).toDouble()
                    : computedThumbTop;
                final displayedPageNumber =
                    useFrozenThumb ? _lastPageNumber ?? pageNumber : pageNumber;

                if (!widget.freezeThumb || _lastThumbTop == null) {
                  _lastThumbTop = computedThumbTop;
                  _lastThumbHeight = computedThumbHeight;
                  _lastPageNumber = pageNumber;
                }

                void jumpToThumbTop(double desiredThumbTop) {
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
                  );
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    jumpToThumbTop(details.localPosition.dy - thumbHeight / 2);
                  },
                  child: Stack(
                    children: [
                      Container(
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
                          onVerticalDragUpdate: (details) {
                            jumpToThumbTop(thumbTop + details.delta.dy);
                          },
                          child: Container(
                            width: widget.trackThickness,
                            height: thumbHeight,
                            decoration: BoxDecoration(
                              color: resolvedThumbColor,
                              borderRadius: BorderRadius.circular(
                                  widget.trackThickness / 2),
                            ),
                            child: Center(
                              child: Text(
                                displayedPageNumber.toString(),
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

/// פס גלילה אופקי דינמי שמתאים את גודלו לפי יחס התוכן הנראה.
class PdfHorizontalScrollbar extends StatelessWidget {
  static const double _minThumbRatio = 0.15;
  static const double _maxThumbRatio = 0.85;
  static const double _minZoomForNormalization = 0.5;
  static const double _zoomRangeForNormalization = 4.5;
  static const double _minThumbWidth = 60.0;
  static const double _maxThumbWidthFactor = 0.95;

  final PdfViewerController controller;
  final double trackThickness;
  final Color? trackColor;
  final Color? thumbColor;

  const PdfHorizontalScrollbar({
    super.key,
    required this.controller,
    this.trackThickness = 8.0,
    this.trackColor,
    this.thumbColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (!controller.isReady) {
          return const SizedBox.shrink();
        }
        try {
          controller.visibleRect;
        } catch (_) {
          return const SizedBox.shrink();
        }

        final zoom = controller.value.zoom;
        final normalizedZoom =
            ((zoom - _minZoomForNormalization) / _zoomRangeForNormalization)
                .clamp(0.0, 1.0);
        final thumbRatio = _maxThumbRatio -
            (normalizedZoom * (_maxThumbRatio - _minThumbRatio));

        final thumbWidth = screenWidth * thumbRatio;
        final maxThumbWidth = screenWidth * _maxThumbWidthFactor;
        final clampedThumbWidth =
            thumbWidth.clamp(_minThumbWidth, maxThumbWidth);

        return PdfViewerScrollThumb(
          controller: controller,
          orientation: ScrollbarOrientation.bottom,
          thumbSize: Size(clampedThumbWidth, trackThickness),
          thumbBuilder: (context, thumbSize, pageNumber, controller) {
            return Container(
              width: thumbSize.width,
              height: trackThickness,
              decoration: BoxDecoration(
                color:
                    thumbColor ?? colorScheme.outline.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(trackThickness / 2),
              ),
            );
          },
        );
      },
    );
  }
}
