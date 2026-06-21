import 'package:flutter/material.dart';
import 'package:otzaria/settings/widgets/settings_action_tile.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';

/// שורת הגדרה עם תפריט נפתח — עוטפת [SettingsActionTile] עם [AppDropdownField].
///
/// הפריסה הרספונסיבית מנוהלת ע"י [SettingsActionTile]:
/// • מסך רחב — הכפתור מימין לטקסט (trailing)
/// • מסך צר   — הכפתור מתחת לטקסט
class DropdownSettingsTile<T> extends StatelessWidget {
  final Widget? icon;
  final String title;
  final String subtitle;
  final T? value;
  final List<AppMenuEntry<T>> entries;
  final ValueChanged<T?> onSelected;
  final bool enableSearch;

  const DropdownSettingsTile({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.entries,
    required this.onSelected,
    this.enableSearch = false,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsActionTile.text(
      icon: icon,
      title: title,
      subtitle: subtitle,
      actions: [
        AppDropdownField<T>(
          value: value,
          entries: entries,
          onSelected: onSelected,
          enableSearch: enableSearch,
          isExpanded: false,
        ),
      ],
    );
  }
}
