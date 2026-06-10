import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/theme/theme_exports.dart';

class ReusableItemsDialog extends StatelessWidget {
  final String title;
  final Widget child;

  const ReusableItemsDialog({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // במסך צר רוחב 50% מקריס את שורות הרשימה לתו-לשורה. מרחיבים ל-95%
    // וב-desktop משאירים 50% כפי שהיה.
    final isNarrow = size.width < LayoutBreakpoints.compact;
    final width = isNarrow ? size.width * 0.95 : size.width * 0.5;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: AppSurfaces.panelBackground(context),
      child: Container(
        width: width,
        height: size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.dismiss_24_regular),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
