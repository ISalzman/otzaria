import 'package:flutter/material.dart';
import 'package:otzaria/theme/app_tokens.dart';

/// טלאי שמצייר עיגול קעור (fillet) במפגש שבין חלונית צד צמודה לתוכן: ריבוע
/// בצבע החלונית שממנו נגרעת רבע-עיגול בצד התוכן, כך שהמפגש מתעגל כלפי החלון.
///
/// מיושם כטלאי נפרד ולא כ-borderRadius כי הקימור פונה *אל* החלונית ולא ממנה.
class ConcaveCornerFillet extends StatelessWidget {
  final Color color;

  /// האם החלונית נמצאת בצד ימין של המסך (הקימור אז פונה שמאלה).
  final bool paneOnRight;

  const ConcaveCornerFillet({
    super.key,
    required this.color,
    required this.paneOnRight,
  });

  /// מידות הטלאי — רבע-עיגול ברדיוס הסטנדרטי.
  static const double size = AppTokens.radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(size),
      painter: _ConcaveCornerPainter(color: color, paneOnRight: paneOnRight),
    );
  }
}

class _ConcaveCornerPainter extends CustomPainter {
  final Color color;
  final bool paneOnRight;

  const _ConcaveCornerPainter({required this.color, required this.paneOnRight});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width;
    // הפינה הפנימית של החלון (שממנה נגרע רבע-העיגול) הפוכה לצד החלונית.
    final carveCenter = paneOnRight ? Offset(0, r) : Offset(r, r);
    canvas.clipRect(Offset.zero & size);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, r, r))
      ..addOval(Rect.fromCircle(center: carveCenter, radius: r));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ConcaveCornerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.paneOnRight != paneOnRight;
}
