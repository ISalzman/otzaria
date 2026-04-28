import 'package:flutter/material.dart';

class SpotlightOverlay extends StatelessWidget {
  final Rect targetRect;
  final List<Rect> targetRects;
  final BorderRadius borderRadius;

  SpotlightOverlay({
    super.key,
    required this.targetRect,
    List<Rect>? targetRects,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  }) : targetRects = targetRects ?? [targetRect];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SpotlightPainter(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.62),
          borderColor: Theme.of(context).colorScheme.primary,
          targetRects: targetRects,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final List<Rect> targetRects;
  final BorderRadius borderRadius;

  const _SpotlightPainter({
    required this.color,
    required this.borderColor,
    required this.targetRects,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = color);

    final rrects = targetRects
        .where((r) => r.width > 0 && r.height > 0)
        .map(borderRadius.toRRect)
        .toList();
    for (final rrect in rrects) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.fill,
      );
    }
    canvas.restore();

    for (final rrect in rrects) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.targetRects != targetRects ||
        oldDelegate.borderRadius != borderRadius;
  }
}
