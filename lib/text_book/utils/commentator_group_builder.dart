import 'package:otzaria/text_book/models/commentator_group.dart';

List<CommentatorGroup> buildCommentatorGroups(
  Map<String, List<String>> eras,
  List<String> availableCommentators,
) {
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

  return [
    CommentatorGroup(
        title: 'תורה שבכתב',
        commentators: eras['תורה שבכתב'] ?? const []),
    CommentatorGroup(
        title: 'חז"ל', commentators: eras['חז"ל'] ?? const []),
    CommentatorGroup(
        title: 'ראשונים', commentators: eras['ראשונים'] ?? const []),
    CommentatorGroup(
        title: 'אחרונים', commentators: eras['אחרונים'] ?? const []),
    CommentatorGroup(
        title: 'מחברי זמננו',
        commentators: eras['מחברי זמננו'] ?? const []),
    CommentatorGroup(title: 'שאר מפרשים', commentators: others),
  ];
}
