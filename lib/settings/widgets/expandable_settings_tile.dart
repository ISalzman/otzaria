import 'package:flutter/material.dart';
import 'package:otzaria/settings/widgets/settings_card.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/widgets/layout/app_card.dart';
import 'package:otzaria/widgets/misc/expanding_chevron.dart';

/// שורת כותרת מורחבת עם תוכן המוסתר/מוצג בלחיצה, לשימוש ב-[AppCard.section].
///
/// הכותרת נבנית דרך [SettingsActionTile] — כך היא יורשת את אותה גלישת טקסט
/// (title בשורה אחת עם ellipsis, subtitle גולש לכמה שורות) ואת אותה נפילה
/// ל-layout אנכי כש-actions לא נכנסים לצד הטקסט.
///
/// מוסיף divider בין הכותרת לתוכן בעת פתיחה, ונמנע מהפער הכפול (3 px)
/// שנוצר כאשר [AnimatedSize] מכווץ ל-0 בין שני ילדים של [AppCard.section].
class ExpandableSection extends StatelessWidget {
  /// key אופציונלי עבור ווידג'ט הכותרת (לדוגמה: מפתח סיור מודרך).
  final Key? headerKey;

  /// אייקון סטטי — לא מתהפך ב-RTL.
  final IconData? icon;

  /// אייקון כיווני — מתהפך ב-RTL אוטומטית.
  final IconData? rtlIcon;

  /// צבע אופציונלי לאייקון.
  final Color? iconColor;

  final String title;
  final String? subtitle;

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
    this.icon,
    this.rtlIcon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    required this.isExpanded,
    required this.children,
    this.hasContent = true,
  }) : assert(icon == null || rtlIcon == null,
            'העבר icon או rtlIcon — לא שניהם יחד');

  @override
  Widget build(BuildContext context) {
    // onTap לא מועבר ל-tile עצמו — ה-InkWell החיצוני מכסה את כל השורה
    // (כולל הצ'בֺרן) כדי שהריחוף ייראה כמו ListTile יחיד, בדיוק כמו קודם.
    final tile = SettingsActionTile.text(
      key: headerKey,
      icon: icon,
      rtlIcon: rtlIcon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      actions: trailing != null ? [trailing!] : const [],
    );

    // הצ'בֺרן נשאר מחוץ ל-actions כדי שיישאר קבוע לצד הטקסט (במרכז אנכי),
    // ולא יגלוש מתחתיו יחד עם trailing כש-SettingsActionTile נופל ל-layout אנכי.
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: tile),
        if (hasContent)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 16),
            child: ExpandingChevron(isExpanded: isExpanded),
          ),
      ],
    );

    final header = hasContent ? InkWell(onTap: onTap, child: row) : row;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        AnimatedSize(
          duration: AppTokens.animNormal,
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: isExpanded && hasContent
                ? [
                    AppCard.sectionDivider(context),
                    for (int i = 0; i < children.length; i++) ...[
                      Material(
                        color: AppSurfaces.card(context),
                        child: children[i],
                      ),
                      if (i < children.length - 1)
                        AppCard.sectionDivider(context),
                    ],
                  ]
                : const [],
          ),
        ),
      ],
    );
  }
}
