import 'package:otzaria/data/data_providers/user_books_database_holder.dart';
import 'package:otzaria/models/link_types.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/user_content_import/repository/user_content_repository.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;

/// טוען קישורי-משתמש (מ-user_books.db) ככ-[Link] עבור ספר שנקרא, בשני
/// הכיוונים:
/// - forward: ספר-המשתמש מקושר ליעד (כשקוראים את ספר-המשתמש עצמו).
/// - inverse: ספר-משתמש אחר מצביע אל הספר הזה (כשקוראים רשמי/אישי שעליו
///   נכתב מפרש-משתמש) — כך מפרש-משתמש מופיע גם בספר הרשמי.
///
/// מחזיר רשימה ריקה אם user_books.db לא פתוח (בלי לכפות פתיחתו).
Future<List<Link>> loadUserLinksForBook({
  required String bookTitle,
  required int? bookCategoryId,
  required bool isUserBook,
  required int startLineIndex,
  required int endLineIndex,
  List<String>? targetBookTitles,
}) async {
  final repo = UserBooksDatabaseHolder.instance.repositoryIfInitialized;
  if (repo == null) return const [];

  final ucr = UserContentRepository(repo.database);
  final result = <Link>[];

  // forward — רק כשקוראים את ספר-המשתמש עצמו.
  if (isUserBook) {
    final sourceId =
        await ucr.bookIdByTitle(bookTitle, categoryId: bookCategoryId);
    if (sourceId != null) {
      final forward = await ucr.forwardUserLinks(
        sourceId,
        startLineIndex: startLineIndex,
        endLineIndex: endLineIndex,
      );
      for (final r in forward) {
        result.add(Link(
          heRef: r.targetRef ?? r.targetTitle,
          index1: r.sourceLineIndex + 1,
          path2: r.targetTitle,
          index2: (r.targetLineIndex ?? -1) + 1,
          connectionType: r.connectionType,
          targetCategoryId: r.targetCategoryId,
          targetIsUserBook: r.targetIsUserBook,
        ));
      }
    }
  }

  // inverse — מפרש-משתמש שמצביע אל הספר הנקרא.
  final inverse = await ucr.inverseUserLinks(
    bookTitle,
    targetIsUserBook: isUserBook,
    targetCategoryId: bookCategoryId,
  );
  for (final r in inverse) {
    final targetLine = r.targetLineIndex;
    final sourceTitle = r.sourceTitle;
    if (targetLine == null || sourceTitle == null) continue;
    if (targetLine < startLineIndex || targetLine > endLineIndex) continue;
    result.add(Link(
      heRef: sourceTitle,
      index1: targetLine + 1,
      path2: sourceTitle,
      index2: r.sourceLineIndex + 1,
      connectionType: r.connectionType,
      targetIsUserBook: true,
    ));
  }

  return _applyCommentatorFilter(result, targetBookTitles);
}

/// מסנן קישורי-מפרש לפי המפרשים הנבחרים (כמו הסינון ב-getLinksForBookRange):
/// קישור תלוי-טקסט נכלל רק אם כותרת היעד נבחרה; קישורי הפניה תמיד עוברים.
List<Link> _applyCommentatorFilter(
  List<Link> links,
  List<String>? targetBookTitles,
) {
  if (targetBookTitles == null) return links;
  final selected = targetBookTitles.toSet();
  return links.where((link) {
    if (!LinkTypes.isDependentTextLink(link.connectionType)) return true;
    return selected.contains(utils.getTitleFromPath(link.path2));
  }).toList();
}
