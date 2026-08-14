import 'package:flutter/material.dart';

/// התנהגות גלילה שמצמידה את פס הגלילה האנכי לצד מבוקש, ולא לקצה ה-trailing
/// שנקבע לפי כיוון הטקסט (בעברית — שמאל). כל מחווני הגלילה של אוצריא יושבים
/// בקצה ימין, וכך גם פסי הגלילה האוטומטיים של הרשימות.
///
/// משכפלת את לוגיקת [MaterialScrollBehavior] (פס אנכי בדסקטופ בלבד) ומוסיפה
/// רק את [orientation].
class EdgeScrollbarBehavior extends MaterialScrollBehavior {
  const EdgeScrollbarBehavior(this.orientation);

  /// פס בקצה ימין — הצד שבו יושבים מחווני הגלילה של אזור הקריאה.
  const EdgeScrollbarBehavior.right()
    : orientation = ScrollbarOrientation.right;

  final ScrollbarOrientation orientation;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) {
      return child;
    }
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(
          controller: details.controller,
          scrollbarOrientation: orientation,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}
