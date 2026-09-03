import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/text_display/models/text_display_profile.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';

/// תת-תפריט "העתק כ..." — וריאציות העתקה שנגזרות מפרופיל ערוץ ההעתקה
/// [base]: מה שהתצוגה נותנת, עם/בלי ניקוד וטעמים, בלי פיסוק. אותה רשימה
/// בגוף, במפרשים ובצורת הדף, כדי שהמשתמש יראה אותן אפשרויות בכל מקום.
List<AppContextMenuEntry> buildCopyAsMenuEntries({
  required TextDisplayProfile base,
  required bool hasSelection,
  required void Function(TextDisplayProfile profile) onCopy,
}) {
  final variants = <({String label, TextDisplayProfile profile})>[
    (label: 'כמו בתצוגה', profile: base),
    (
      label: 'עם ניקוד וטעמים',
      profile: base.copyWith(
        nikud: MarkVisibility.show,
        teamim: TeamimVisibility.show,
      ),
    ),
    (
      label: 'עם ניקוד, בלי טעמים',
      profile: base.copyWith(
        nikud: MarkVisibility.show,
        teamim: TeamimVisibility.hide,
      ),
    ),
    (
      label: 'בלי ניקוד וטעמים',
      profile: base.copyWith(
        nikud: MarkVisibility.hide,
        teamim: TeamimVisibility.hide,
      ),
    ),
    (
      label: 'בלי ניקוד, טעמים ופיסוק',
      profile: base.copyWith(
        nikud: MarkVisibility.hide,
        teamim: TeamimVisibility.hide,
        punctuation: MarkVisibility.hide,
      ),
    ),
    (
      label: base.replaceHolyNames ? 'שם הוי"ה ככתבו' : 'שם הוי"ה כיקוק',
      profile: base.copyWith(
        holyName: base.replaceHolyNames
            ? HolyNameDisplay.asIs
            : HolyNameDisplay.kufKuf,
      ),
    ),
  ];
  // וריאציה שזהה לבסיס (למעט הראשונה) מיותרת — לא מציגים אותה פעמיים.
  final seen = <TextDisplayProfile>{};
  return [
    for (final variant in variants)
      if (seen.add(variant.profile))
        AppContextMenuEntry(
          label: variant.label,
          icon: identical(variant.profile, base)
              ? FluentIcons.copy_24_regular
              : FluentIcons.text_clear_formatting_24_regular,
          enabled: hasSelection,
          onTap: () => onCopy(variant.profile),
        ),
  ];
}
