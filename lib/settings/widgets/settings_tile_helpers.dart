import 'package:flutter/material.dart';
import 'package:otzaria/theme/theme_exports.dart';

/// בלוק אייקון + כותרת + תת-כותרת — תבנית חוזרת בשורות הגדרה רספונסיביות.
///
/// משמש ב-[DropdownSettingsTile] וב-[SegmentedSettingsTile] בלייאוט הצר.
///
/// [icon] יכול להיות [Icon] רגיל או [RtlIcon] — הקורא מחליט.
class SettingsTileInfo extends StatelessWidget {
  /// ווידג'ט האייקון — [Icon] או [RtlIcon] לפי בחירת הקורא.
  final Widget? icon;

  /// [String] או [Widget].
  final dynamic title;
  final String? subtitle;

  const SettingsTileInfo({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          icon!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              title is String
                  ? Text(title as String, style: AppTextStyles.settingTitle)
                  : title as Widget,
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTextStyles.settingSubtitle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
