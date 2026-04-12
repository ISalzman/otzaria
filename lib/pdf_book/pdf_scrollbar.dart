import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

typedef PdfScrollBoundsBuilder = Rect? Function(PdfViewerController controller);

/// פס גלילה מותאם אישית ל-PDF עם track מלא.
class PdfScrollbar extends StatelessWidget {
  final PdfViewerController controller;
  final ScrollbarOrientation orientation;
  final double trackThickness;
  final Color? trackColor;
  final Color? thumbColor;
  final double thumbMinSize;
  final PdfScrollBoundsBuilder? scrollBoundsBuilder;

  const PdfScrollbar({
    super.key,
    required this.controller,
    required this.orientation,
    this.trackThickness = 12.0,
    this.trackColor,
    this.thumbColor,
    this.thumbMinSize = 40.0,
    this.scrollBoundsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isVertical = orientation == ScrollbarOrientation.right ||
        orientation == ScrollbarOrientation.left;

    if (!isVertical || scrollBoundsBuilder == null) {
      return PdfViewerScrollThumb(
        controller: controller,
        orientation: orientation,
        thumbSize: isVertical
            ? Size(trackThickness, thumbMinSize)
            : Size(thumbMinSize, trackThickness),
        thumbBuilder: (context, thumbSize, pageNumber, controller) {
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            width: isVertical ? trackThickness : thumbSize.width,
            height: isVertical ? thumbSize.height : trackThickness,
            decoration: BoxDecoration(
              color: thumbColor ?? colorScheme.outline.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(trackThickness / 2),
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
    }

    final alignment = orientation == ScrollbarOrientation.left
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedTrackColor =
        trackColor ?? colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);
    final resolvedThumbColor =
        thumbColor ?? colorScheme.primary.withValues(alpha: 0.82);

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, child) {
        if (!controller.isReady) {
          return const SizedBox.shrink();
        }

        final bounds = scrollBoundsBuilder!(controller);
        if (bounds == null) {
          return const SizedBox.shrink();
        }

        final visibleRect = controller.visibleRect;
        final visibleHeight = math.min(visibleRect.height, bounds.height);
        final scrollableExtent = math.max(bounds.height - visibleHeight, 0.0);
        final currentTop =
            (visibleRect.top - bounds.top).clamp(0.0, scrollableExtent).toDouble();

        return Align(
          alignment: alignment,
          child: SizedBox(
            width: trackThickness,
            height: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                if (trackHeight <= 0) {
                  return const SizedBox.shrink();
                }

                final rawThumbHeight = bounds.height <= 0
                    ? trackHeight
                    : trackHeight * (visibleHeight / bounds.height);
                final thumbHeight = rawThumbHeight.clamp(thumbMinSize, trackHeight);
                final maxThumbTop = math.max(trackHeight - thumbHeight, 0.0);
                final thumbTop = scrollableExtent == 0
                    ? 0.0
                    : maxThumbTop * (currentTop / scrollableExtent);

                void jumpToThumbTop(double desiredThumbTop) {
                  if (maxThumbTop <= 0) return;
                  final normalizedTop =
                      (desiredThumbTop.clamp(0.0, maxThumbTop) / maxThumbTop)
                          .toDouble();
                  final targetTop = bounds.top + normalizedTop * scrollableExtent;
                  final targetCenter = Offset(
                    visibleRect.center.dx,
                    targetTop + visibleHeight / 2,
                  );
                  controller.goTo(
                    controller.calcMatrixFor(
                      targetCenter,
                      zoom: value.zoom,
                      viewSize: controller.viewSize,
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
                        width: trackThickness,
                        decoration: BoxDecoration(
                          color: resolvedTrackColor,
                          borderRadius: BorderRadius.circular(trackThickness / 2),
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
                            width: trackThickness,
                            height: thumbHeight,
                            decoration: BoxDecoration(
                              color: resolvedThumbColor,
                              borderRadius:
                                  BorderRadius.circular(trackThickness / 2),
                            ),
                            child: Center(
                              child: Text(
                                (controller.pageNumber ?? 1).toString(),
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

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, child) {
        if (!controller.isReady) {
          return const SizedBox.shrink();
        }

        final zoom = value.zoom;
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
                color: thumbColor ?? colorScheme.outline.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(trackThickness / 2),
              ),
            );
          },
        );
      },
    );
  }
}
