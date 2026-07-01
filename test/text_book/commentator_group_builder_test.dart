import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/text_book/models/commentator_group.dart';
import 'package:otzaria/text_book/utils/commentator_group_builder.dart';

/// טסטים להקדמת המפרשים הבסיסיים בתוך קבוצות הדורות (דרישה א).
void main() {
  List<String> groupNamed(List<CommentatorGroup> groups, String title) =>
      groups.firstWhere((g) => g.title == title).commentators;

  Link commentaryLink(int index1, String title) => Link(
        heRef: title,
        index1: index1,
        path2: title,
        index2: 1,
        connectionType: 'COMMENTARY',
      );

  group('computeRareCommentators - הסתרת מפרשים נדירים', () {
    test('ספר גדול: מסתיר מפרשים עם פחות מ-10 קישורים בלבד', () {
      final rare = computeRareCommentators(
        bookTotalLines: 500,
        linkCountByCommentator: {
          'רש"י': 300,
          'מפרש נדיר': 3,
          'בדיוק על הסף': 10,
          'מתחת לסף': 9,
        },
      );

      expect(rare, {'מפרש נדיר', 'מתחת לסף'});
    });

    test('ספר קטן (עד 100 שורות): אין הסתרה כלל', () {
      final rare = computeRareCommentators(
        bookTotalLines: 100,
        linkCountByCommentator: {'מפרש נדיר': 1},
      );

      expect(rare, isEmpty);
    });
  });

  group('lineRelevantRareCommentators - חשיפת נדירים על השורה הנוכחית', () {
    final rare = {'מפרש נדיר', 'נדיר אחר'};
    // linksByLine ממופתח 1-based (idx+1); השורה 0 → מפתח 1.
    final linksByLine = {
      1: [commentaryLink(1, 'רש"י'), commentaryLink(1, 'מפרש נדיר')],
      6: [commentaryLink(6, 'נדיר אחר')],
    };

    test('מחזיר רק נדירים שיש להם קישור על אחת השורות הנוכחיות', () {
      final relevant = lineRelevantRareCommentators(
        rareCommentators: rare,
        currentIndexes: const [0],
        linksByLine: linksByLine,
      );

      expect(relevant, {'מפרש נדיר'});
    });

    test('שורה ללא קישור ממפרש נדיר מחזירה קבוצה ריקה', () {
      final relevant = lineRelevantRareCommentators(
        rareCommentators: rare,
        currentIndexes: const [2],
        linksByLine: linksByLine,
      );

      expect(relevant, isEmpty);
    });

    test('קבוצת נדירים ריקה — לא מחשב דבר', () {
      final relevant = lineRelevantRareCommentators(
        rareCommentators: const {},
        currentIndexes: const [0],
        linksByLine: linksByLine,
      );

      expect(relevant, isEmpty);
    });
  });

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
