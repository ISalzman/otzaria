import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/text_book/models/commentator_group.dart';
import 'package:otzaria/text_book/utils/commentator_group_builder.dart';

/// טסטים להקדמת המפרשים הבסיסיים בתוך קבוצות הדורות (דרישה א).
void main() {
  List<String> groupNamed(List<CommentatorGroup> groups, String title) =>
      groups.firstWhere((g) => g.title == title).commentators;

  group('buildCommentatorGroups - הקדמת מפרשים בסיסיים', () {
    test('מקדים מפרש בסיסי לראש קבוצת הדור שלו, שאר המפרשים בסדר המקורי', () {
      final eras = {
        'ראשונים': ['רמב"ן', 'רש"י', 'רשב"א'],
        'אחרונים': ['מהרש"א'],
      };

      final groups = buildCommentatorGroups(
        eras,
        ['רמב"ן', 'רש"י', 'רשב"א', 'מהרש"א'],
        baseCommentators: ['רש"י'],
      );

      expect(groupNamed(groups, 'ראשונים'), ['רש"י', 'רמב"ן', 'רשב"א']);
    });

    test('שומר על סדר ה-position בין כמה מפרשים בסיסיים באותה קבוצה', () {
      final eras = {
        'ראשונים': ['רמב"ן', 'רש"י', 'תוספות'],
      };

      final groups = buildCommentatorGroups(
        eras,
        ['רמב"ן', 'רש"י', 'תוספות'],
        // position: תוספות (0) לפני רש"י (1)
        baseCommentators: ['תוספות', 'רש"י'],
      );

      expect(groupNamed(groups, 'ראשונים'), ['תוספות', 'רש"י', 'רמב"ן']);
    });

    test('ללא מפרשים בסיסיים - הסדר המקורי נשמר', () {
      final eras = {
        'ראשונים': ['רמב"ן', 'רש"י'],
      };

      final groups = buildCommentatorGroups(eras, ['רמב"ן', 'רש"י']);

      expect(groupNamed(groups, 'ראשונים'), ['רמב"ן', 'רש"י']);
    });

    test('מפרש בסיסי שאינו שייך לקבוצה אינו משפיע עליה', () {
      final eras = {
        'ראשונים': ['רמב"ן'],
      };

      final groups = buildCommentatorGroups(
        eras,
        ['רמב"ן'],
        baseCommentators: ['רש"י'], // לא קיים ברשימת המפרשים
      );

      expect(groupNamed(groups, 'ראשונים'), ['רמב"ן']);
    });
  });
}
