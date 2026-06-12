import 'package:flutter/material.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/layout/app_card.dart';
import 'package:otzaria/widgets/misc/expanding_chevron.dart';

/// שורת כותרת מורחבת עם תוכן המוסתר/מוצג בלחיצה, לשימוש ב-[AppCard.section].
///
/// מוסיף divider בין הכותרת לתוכן בעת פתיחה, ונמנע מהפער הכפול (3 px)
/// שנוצר כאשר [AnimatedSize] מכווץ ל-0 בין שני ילדים של [AppCard.section].
class ExpandableSection extends StatelessWidget {
  /// key אופציונלי עבור ווידג'ט הכותרת (לדוגמה: מפתח סיור מודרך).
  final Key? headerKey;
  final Widget icon;
  final Widget title;
  final Widget? subtitle;

  /// ווידג'ט אופציונלי לפני הצ'בֺרן (לדוגמה: [AppSegmentedControl]).
  final Widget? trailing;

  final VoidCallback onTap;
  final bool isExpanded;
  final List<Widget> children;

  /// כשאין תוכן להצגה, הצ'בֺרן מוסתר והלחיצה מושבתת.
  final bool hasContent;

  const ExpandableSection({
    super.key,
    this.headerKey,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    required this.isExpanded,
    required this.children,
    this.hasContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final header = ListTile(
      key: headerKey,
      leading: icon,
      title: DefaultTextStyle.merge(
        style: AppTextStyles.settingTitle,
        child: title,
      ),
      subtitle: subtitle != null
          ? DefaultTextStyle.merge(
              style: AppTextStyles.settingSubtitle,
              child: subtitle!,
            )
          : null,
      trailing: trailing != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                trailing!,
                if (hasContent) ...[
                  const SizedBox(width: 12),
                  ExpandingChevron(isExpanded: isExpanded),
                ],
              ],
            )
          : hasContent
              ? ExpandingChevron(isExpanded: isExpanded)
              : null,
      onTap: hasContent ? onTap : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        AnimatedSize(
          duration: AppTokens.animNormal,
          curve: Curves.easeInOut,
          child: isExpanded && hasContent
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppCard.sectionDivider(context),
                    for (int i = 0; i < children.length; i++) ...[
                      Material(
                        color: AppSurfaces.card(context),
                        child: children[i],
                      ),
                      if (i < children.length - 1)
                        AppCard.sectionDivider(context),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
