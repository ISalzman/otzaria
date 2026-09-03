import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/widgets/misc/middle_click_autoscroll.dart';

/// פריט שלחיצת גלגל העכבר עליו מפעילה [onMiddleClick] — "פתח בכרטיסייה
/// חדשה" כמו בדפדפן. לחיצת הגלגל שמורה לכך, ולכן האוטו-גלילה לא תופעל בו.
class MiddleClickOpen extends StatelessWidget {
  const MiddleClickOpen({
    super.key,
    required this.onMiddleClick,
    required this.child,
  });

  final VoidCallback onMiddleClick;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (event.kind != PointerDeviceKind.mouse) return;
        if (event.buttons != kMiddleMouseButton) return;
        onMiddleClick();
      },
      child: AutoScrollBarrier(child: child),
    );
  }
}
