import 'package:otzaria/models/books.dart';

/// פריט יחיד ברשימה השטוחה של ה-TOC.
/// משמש כשעוברים למצב וירטואליזציה אמיתית (ספרים עם הרבה ערכי TOC).
class TocFlatItem {
  final TocEntry entry;
  final bool isExpanded;
  const TocFlatItem(this.entry, this.isExpanded);

  @override
  bool operator ==(Object other) =>
      other is TocFlatItem &&
      other.entry == entry &&
      other.isExpanded == isExpanded;

  @override
  int get hashCode => Object.hash(entry, isExpanded);
}

/// סופר רקורסיבית את כל ערכי ה-TOC (כל הרמות).
/// משמש כדי להחליט אם לעבור למצב וירטואלי שטוח.
int countAllTocEntries(List<TocEntry> entries) {
  var count = entries.length;
  for (final e in entries) {
    count += countAllTocEntries(e.children);
  }
  return count;
}

/// מחזיר את הערכים הגלויים כרגע ברשימה שטוחה (לפי [expanded]).
///
/// כללי הרחבה ברירת-מחדל (כשאין הכרעה ב-[expanded]):
/// - ערך ברמה 1 מורחב.
/// - "ילד ראשון" של אב מורחב מורחב גם הוא (שרשרת first-child).
///
/// המפה [expanded] מאפשרת למשתמש לעקוף את ברירת המחדל - הערך בה
/// קובע הכל אם קיים (true=מורחב, false=מכווץ).
///
/// [expandByDefault] פותח הכל כברירת מחדל - כך נראות תוצאות החיפוש.
List<TocFlatItem> flattenVisibleToc(
  List<TocEntry> entries,
  Map<int, bool> expanded, {
  bool parentIsFirstChild = true,
  bool expandByDefault = false,
}) {
  final result = <TocFlatItem>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final isFirstChild = parentIsFirstChild && i == 0;

    if (entry.children.isEmpty) {
      result.add(TocFlatItem(entry, false));
      continue;
    }

    final fallbackExpanded =
        expandByDefault || entry.level == 1 || isFirstChild;
    final isExpanded = expanded[entry.index] ?? fallbackExpanded;
    result.add(TocFlatItem(entry, isExpanded));
    if (isExpanded) {
      result.addAll(
        flattenVisibleToc(
          entry.children,
          expanded,
          parentIsFirstChild: isFirstChild,
          expandByDefault: expandByDefault,
        ),
      );
    }
  }
  return result;
}

/// מחזירה עותק של [toc] שבו כל דיבור-מתחיל ב-[dibburim] (`lineIndex` → טקסט)
/// הוא עלה תחת הכותרת האחרונה שלפניו בסדר הספר — גם כשזו כותרת שהייתה עלה
/// בעצמה. העץ המקורי אינו משתנה, ולכן "הכותרת הנוכחית", הסימניות וההעתקה
/// ממשיכים להתייחס לכותרות בלבד. דיבור שלפני הכותרת הראשונה נשמט.
List<TocEntry> attachDibburimToToc(
  List<TocEntry> toc,
  Map<int, String> dibburim,
) {
  if (dibburim.isEmpty) return toc;

  final lineIndexes = dibburim.keys.toList()..sort();
  var nextDibbur = 0;
  TocEntry? lastHeading;

  // מצרף ל-[lastHeading] את כל הדיבורים שלפני הכותרת הבאה (או את כולם).
  void attachDibburimBefore(int? nextHeadingIndex) {
    while (nextDibbur < lineIndexes.length &&
        (nextHeadingIndex == null ||
            lineIndexes[nextDibbur] < nextHeadingIndex)) {
      final lineIndex = lineIndexes[nextDibbur++];
      final heading = lastHeading;
      if (heading == null) continue;
      heading.children.add(
        TocEntry(
          text: dibburim[lineIndex]!,
          index: lineIndex,
          level: heading.level + 1,
          parent: heading,
        ),
      );
    }
    // דיבור על שורת הכותרת עצמה אינו קיים במסד; אם בכל זאת הגיע — נשמט.
    if (nextHeadingIndex != null &&
        nextDibbur < lineIndexes.length &&
        lineIndexes[nextDibbur] == nextHeadingIndex) {
      nextDibbur++;
    }
  }

  List<TocEntry> copyLevel(List<TocEntry> entries, TocEntry? parent) {
    return [
      for (final entry in entries)
        () {
          attachDibburimBefore(entry.index);
          final copy = TocEntry(
            text: entry.text,
            index: entry.index,
            level: entry.level,
            parent: parent,
          );
          lastHeading = copy;
          copy.children.addAll(copyLevel(entry.children, copy));
          return copy;
        }(),
    ];
  }

  final result = copyLevel(toc, null);
  attachDibburimBefore(null);
  return result;
}
