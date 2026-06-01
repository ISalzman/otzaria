import 'package:otzaria/text_book/models/commentator_group.dart';

/// בונה את קבוצות המפרשים לפי דורות.
///
/// [baseCommentators] - המפרשים הבסיסיים של הספר (ממוינים לפי position).
/// בתוך כל קבוצה הם מוקדמים לראש הרשימה בסדר זה, ושאר המפרשים אחריהם.
List<CommentatorGroup> buildCommentatorGroups(
  Map<String, List<String>> eras,
  List<String> availableCommentators, {
  List<String> baseCommentators = const [],
}) {
  final known = <String>{
    ...?eras['תורה שבכתב'],
    ...?eras['חז"ל'],
    ...?eras['ראשונים'],
    ...?eras['אחרונים'],
    ...?eras['מחברי זמננו'],
  };

  final others = (eras['מפרשים נוספים'] ?? [])
      .toSet()
      .union(availableCommentators
          .where((c) => !known.contains(c))
          .toList()
          .toSet())
      .toList();

  List<String> promote(List<String> commentators) =>
      _promoteBase(commentators, baseCommentators);

  return [
    CommentatorGroup(
        title: 'תורה שבכתב',
        commentators: promote(eras['תורה שבכתב'] ?? const [])),
    CommentatorGroup(
        title: 'חז"ל', commentators: promote(eras['חז"ל'] ?? const [])),
    CommentatorGroup(
        title: 'ראשונים', commentators: promote(eras['ראשונים'] ?? const [])),
    CommentatorGroup(
        title: 'אחרונים', commentators: promote(eras['אחרונים'] ?? const [])),
    CommentatorGroup(
        title: 'מחברי זמננו',
        commentators: promote(eras['מחברי זמננו'] ?? const [])),
    CommentatorGroup(title: 'שאר מפרשים', commentators: promote(others)),
  ];
}

/// מקדים את המפרשים הבסיסיים לראש הקבוצה (בסדר [base]), ושאר המפרשים אחריהם
/// בסדר המקורי. אם אין מפרשים בסיסיים בקבוצה - מוחזרת הרשימה ללא שינוי.
List<String> _promoteBase(List<String> commentators, List<String> base) {
  if (base.isEmpty || commentators.isEmpty) return commentators;

  final commentatorsSet = commentators.toSet();
  final baseInGroup =
      base.where(commentatorsSet.contains).toList(); // לפי סדר position
  if (baseInGroup.isEmpty) return commentators;

  final baseSet = baseInGroup.toSet();
  final rest = commentators.where((c) => !baseSet.contains(c)).toList();
  return [...baseInGroup, ...rest];
}
