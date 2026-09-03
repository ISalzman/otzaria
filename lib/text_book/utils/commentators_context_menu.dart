import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:otzaria/models/link_types.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/text_book/models/commentator_group.dart';
import 'package:otzaria/text_book/utils/inline_notes_utils.dart'
    as inline_notes;
import 'package:otzaria/utils/text/text_manipulation.dart'
    show getTitleFromPath;
import 'package:otzaria/widgets/misc/app_menu_exports.dart';

/// כותרת תת-התפריט "מפרשים" בתפריט ההקשר של גוף הספר.
const String kParagraphCommentatorsMenuLabel = 'מפרשים על פסקה זו';

/// המפרשים מתוך [availableCommentators] שיש להם תוכן על הפסקה [paragraphIndex]
/// (0-based): קישור-מפרש ב-[linksByLine] (ממופתח 1-based), או הערות inline
/// בשורה עבור המפרש הוירטואלי [kNotesCommentatorTitle]. הסדר נשמר.
List<String> paragraphCommentators({
  required List<String> availableCommentators,
  required List<String> content,
  required int paragraphIndex,
  required Map<int, List<Link>> linksByLine,
}) {
  final onParagraph = <String>{};
  for (final link in linksByLine[paragraphIndex + 1] ?? const <Link>[]) {
    if (!LinkTypes.isDependentTextLink(link.connectionType)) continue;
    onParagraph.add(getTitleFromPath(link.path2));
  }
  if (inline_notes.notesForLines(content, [paragraphIndex]).isNotEmpty) {
    onParagraph.add(kNotesCommentatorTitle);
  }
  return availableCommentators.where(onParagraph.contains).toList();
}

/// פריט "פתח את חלונית המפרשים" יוצג כשיש מפרשים נבחרים, המפרשים אינם מוצגים
/// inline מתחת לטקסט, וטאב המפרשים אינו כבר פעיל בחלונית הצד.
bool shouldShowOpenCommentatorsPaneEntry({
  required bool hasSelectedCommentators,
  required bool showCommentaryAsExpansionTiles,
  required bool isCommentatorsTabActive,
}) {
  return hasSelectedCommentators &&
      !showCommentaryAsExpansionTiles &&
      !isCommentatorsTabActive;
}

/// פריט "בחר מפרשים מרובים" יוצג כשיש callback לפתיחת חלונית הסינון וטאב
/// המפרשים אינו פעיל בחלונית הצד.
///
/// בניגוד ל-[shouldShowOpenCommentatorsPaneEntry], הפריט הזה לא תלוי
/// ב-`hasSelectedCommentators` — מטרתו לאפשר בחירה גם כשהבחירה ריקה.
bool shouldShowSelectCommentatorsEntry({
  required bool hasOpenCommentatorsPaneWithFilterCallback,
  required bool isCommentatorsTabActive,
}) {
  return hasOpenCommentatorsPaneWithFilterCallback && !isCommentatorsTabActive;
}

/// נקרא כשבחירת המפרשים משתנה מתוך תת-התפריט.
///
/// [commentators] - הבחירה המעודכנת המלאה.
/// [isAdding] - האם הפעולה הוסיפה מפרשים (ולכן כדאי לפתוח את החלונית).
typedef CommentatorsSelectionChanged =
    void Function(List<String> commentators, {required bool isAdding});

/// בונה את פריטי תת-התפריט "מפרשים על פסקה זו" בתפריט ההקשר של גוף הספר.
///
/// משותף לתצוגה המשולבת/מפוצלת ולצורת הדף, כדי ששלושתן יציגו את אותם פריטים
/// ואותה התנהגות. [availableCommentators] הם מפרשי הפסקה בלבד (ראו
/// [paragraphCommentators]); הקבוצות מסוננות לפיהם.
///
/// [onOpenPane] ו-[onSelectMultiple] אינם מוצגים כשהם `null`. כשאין מפרשים
/// לפסקה מוצגים רק פריטי הפתיחה, ובזמן [linksLoading] גם פריט "טוען…" מושבת.
List<AppContextMenuEntry> buildCommentatorsContextMenuChildren({
  required List<String> activeCommentators,
  required List<String> availableCommentators,
  required List<CommentatorGroup> commentatorGroups,
  required CommentatorsSelectionChanged onCommentatorsChanged,
  VoidCallback? onOpenPane,
  VoidCallback? onSelectMultiple,
  bool linksLoading = false,
}) {
  final activeSet = activeCommentators.toSet();
  final availableSet = availableCommentators.toSet();
  final allActive = activeSet.containsAll(availableCommentators);

  List<AppContextMenuEntry> buildGroup(CommentatorGroup group) {
    final commentators = group.commentators.where(availableSet.contains);
    if (commentators.isEmpty) return const <AppContextMenuEntry>[];
    final groupActive = commentators.every(activeSet.contains);
    return [
      AppContextMenuEntry(
        label: 'הצג את כל ${group.title}',
        isSelected: groupActive,
        onTap: () {
          final updated = List<String>.from(activeCommentators);
          if (groupActive) {
            updated.removeWhere(commentators.contains);
          } else {
            for (final title in commentators) {
              if (!updated.contains(title)) updated.add(title);
            }
          }
          onCommentatorsChanged(updated, isAdding: !groupActive);
        },
      ),
      ...commentators.map((title) {
        final isActive = activeSet.contains(title);
        return AppContextMenuEntry(
          label: title,
          isSelected: isActive,
          onTap: () {
            // מפרש פעיל אינו מוסר מכאן — לחיצה עליו רק פותחת את החלונית.
            // הסרה שקטה גרמה ללולאת הוסף/הסר בכל ניסיון חוזר (issue #904).
            final updated = List<String>.from(activeCommentators);
            if (!isActive) updated.add(title);
            onCommentatorsChanged(updated, isAdding: true);
          },
        );
      }),
    ];
  }

  final entries = <AppContextMenuEntry>[
    if (onOpenPane != null)
      AppContextMenuEntry(
        label: 'פתח את חלונית המפרשים',
        icon: FluentIcons.panel_right_24_regular,
        isHighlighted: true,
        onTap: onOpenPane,
      ),
    if (onSelectMultiple != null)
      AppContextMenuEntry(
        label: 'בחר מפרשים מרובים',
        icon: FluentIcons.filter_24_regular,
        isHighlighted: true,
        onTap: onSelectMultiple,
      ),
    if (onOpenPane != null || onSelectMultiple != null)
      const AppContextMenuEntry.divider(),
    if (availableCommentators.isEmpty && linksLoading)
      const AppContextMenuEntry(label: 'טוען מפרשים…', enabled: false),
    if (availableCommentators.isNotEmpty)
      AppContextMenuEntry(
        label: 'הצג את כל המפרשים על פסקה זו',
        isSelected: allActive,
        onTap: () => onCommentatorsChanged(
          allActive ? <String>[] : List<String>.from(availableCommentators),
          isAdding: !allActive,
        ),
      ),
  ];

  // הקבוצות מגיעות מה-BLoC כשהן כבר ממוינות לפי דורות; מפריד מתווסף רק לפני
  // קבוצה שיש בה מפרשים, כדי שקבוצה ריקה באמצע לא תדביק שתי קבוצות זו לזו.
  for (final group in commentatorGroups) {
    final items = buildGroup(group);
    if (items.isEmpty) continue;
    entries.add(const AppContextMenuEntry.divider());
    entries.addAll(items);
  }

  return entries;
}
