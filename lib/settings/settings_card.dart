import 'package:flutter/material.dart';
import 'package:otzaria/theme/theme_exports.dart';

/// Divider זהה לסגנון הפנימי של SettingsCard — לשימוש בתוכן מורחב (AnimatedSize וכד')
///
/// שימוש:
///   settingsCardDivider(context)
Divider settingsCardDivider(BuildContext context) => Divider(
      height: 1,
      thickness: 1.5,
      indent: 0,
      endIndent: 0,
      color: Theme.of(context).scaffoldBackgroundColor,
    );

/// כרטיס הגדרות מעוצב בסגנון Material 3 / Google Account
class SettingsCard extends StatelessWidget {
  final dynamic title; // יכול להיות String או Widget
  final String? subtitle;
  final List<Widget> children;

  const SettingsCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = AppSurfaces.card(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // כותרת ותת-כותרת מעל הכרטיס
        Padding(
          padding:
              const EdgeInsets.only(right: 16, left: 16, top: 24, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title is String
                  ? Text(
                      title as String,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : DefaultTextStyle(
                      style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ) ??
                          const TextStyle(),
                      child: title as Widget,
                    ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        // הכרטיס המכיל את ההגדרות
        ClipRRect(
          borderRadius:
              const BorderRadius.all(Radius.circular(AppTokens.radiusXL)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _buildChildrenWithDividers(context, cardColor),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChildrenWithDividers(
      BuildContext context, Color cardColor) {
    return [
      for (int i = 0; i < children.length; i++) ...[
        ColoredBox(color: cardColor, child: children[i]),
        if (i < children.length - 1) const SizedBox(height: 1.5),
      ],
    ];
  }
}
