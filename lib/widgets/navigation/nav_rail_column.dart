import 'package:flutter/material.dart';

/// עמודת סרגל הניווט הצדי: [items] למעלה, [bottomItem] צמוד לתחתית.
///
/// כשגובה החלון קטן מדי (מקלדת וירטואלית פתוחה) העמודה גולשת במקום לחרוג —
/// אין להחליף בחישוב גובה משוער לפריט, שאינו מדויק ומחזיר את החריגה.
class NavRailColumn extends StatelessWidget {
  const NavRailColumn({
    super.key,
    required this.items,
    required this.bottomItem,
  });

  /// פריטי הניווט העליונים, לפי סדרם.
  final List<Widget> items;

  /// הפריט הצמוד לתחתית הסרגל (הגדרות).
  final Widget bottomItem;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [...items, const Spacer(), bottomItem],
              ),
            ),
          ),
        );
      },
    );
  }
}
