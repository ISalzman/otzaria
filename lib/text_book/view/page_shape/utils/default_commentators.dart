import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';

/// מחלקה לניהול מפרשי ברירת המחדל ("מפרשים בסיסיים") של ספר.
///
/// המקור הבלעדי לנתונים הוא טבלאות `default_commentator` ו-`default_targum`
/// ב-seforim.db. ה-`position` ממיין כל טבלה בנפרד (אין מרחב position משותף
/// בין שתי הטבלאות) — הוא קובע את סדר ההקדמה ברשימה ואת סדר המיקומים בצורת
/// הדף בתוך כל סוג. היחס בין מפרשים לתרגומים קבוע: המפרשים תמיד קודמים
/// לתרגומים (ב-[getBaseCommentators] וב-[getDefaults] כאחד).
class DefaultCommentators {
  /// מחזיר את מפרשי ותרגומי ברירת המחדל של [book], ממוינים לפי `position`.
  ///
  /// ספרים אישיים אינם נכללים ב-seforim.db ולכן מחזירים רשימות ריקות.
  static Future<({List<String> commentators, List<String> targums})>
      _fetchDefaults(TextBook book) async {
    const empty = (commentators: <String>[], targums: <String>[]);

    if (book.isUserBook) return empty;

    final repository = SqliteDataProvider.instance.repository;
    if (repository == null) return empty;

    final dbBook = book.categoryId != null
        ? await repository.getBookByTitleAndCategory(
            book.title, book.categoryId!)
        : await repository.getBookByTitle(book.title);
    if (dbBook == null) return empty;

    final linkDao = repository.database.linkDao;
    final commentatorRows = await linkDao.selectDefaultCommentators(dbBook.id);
    final targumRows = await linkDao.selectDefaultTargums(dbBook.id);

    return (
      commentators: commentatorRows
          .map((row) => row['targetBookTitle'] as String)
          .toList(),
      targums:
          targumRows.map((row) => row['targetBookTitle'] as String).toList(),
    );
  }

  /// מחזיר את רשימת המפרשים הבסיסיים של [book] (מפרשים ואחריהם תרגומים),
  /// ממוינת לפי `position`. משמש להקדמת המפרשים הבסיסיים בתוך קבוצות הדורות.
  static Future<List<String>> getBaseCommentators(TextBook book) async {
    final data = await _fetchDefaults(book);
    return [...data.commentators, ...data.targums];
  }

  /// מחזיר מפרשי ברירת מחדל למיקומי צורת הדף (right/left/bottom/bottomRight).
  ///
  /// המיפוי: המפרשים והתרגומים מאוחדים לרשימה אחת לפי `position` (מפרשים
  /// ואחריהם תרגומים), והמיקומים ממולאים לפי הסדר: ימין, שמאל, תחתון,
  /// תחתון-ימני. כלומר המפרש הראשון בימין, השני בשמאל וכן הלאה.
  /// [availableCommentators] משמש להתאמת השם המלא הזמין בספר הנוכחי.
  static Future<Map<String, String?>> getDefaults(
    TextBook book, {
    List<String>? availableCommentators,
  }) async {
    final data = await _fetchDefaults(book);
    final defaults = mapToPageShape(data.commentators, data.targums);

    if (availableCommentators != null && availableCommentators.isNotEmpty) {
      return _resolveCommentatorNamesFromAvailable(
          defaults, availableCommentators);
    }

    return defaults;
  }

  /// ממפה רשימת מפרשים ותרגומים (מאוחדים לפי position) ל-4 מיקומי צורת הדף
  /// לפי הסדר: ימין, שמאל, תחתון, תחתון-ימני.
  @visibleForTesting
  static Map<String, String?> mapToPageShape(
    List<String> commentators,
    List<String> targums,
  ) {
    final all = [...commentators, ...targums];
    String? at(int index) => index < all.length ? all[index] : null;

    return {
      'right': at(0),
      'left': at(1),
      'bottom': at(2),
      'bottomRight': at(3),
    };
  }

  static Map<String, String?> _resolveCommentatorNamesFromAvailable(
      Map<String, String?> defaults, List<String> availableCommentators) {
    return {
      'right':
          _findMatchingCommentator(defaults['right'], availableCommentators),
      'left': _findMatchingCommentator(defaults['left'], availableCommentators),
      'bottom':
          _findMatchingCommentator(defaults['bottom'], availableCommentators),
      'bottomRight': _findMatchingCommentator(
          defaults['bottomRight'], availableCommentators),
    };
  }

  /// מחפש מפרש שמתאים לשם הנתון מתוך הזמינים בפועל בספר.
  /// מחזיר את השם המלא אם נמצא, או null אם לא.
  static String? _findMatchingCommentator(
      String? name, List<String> available) {
    if (name == null) return null;

    // 1. התאמה מדויקת
    String? match = available.firstWhereOrNull((item) => item == name);
    if (match != null) return match;

    // 2. התאמה של התחלה
    match = available.firstWhereOrNull((item) => item.startsWith(name));
    if (match != null) return match;

    // 3. התאמה של הכלה
    match = available.firstWhereOrNull((item) => item.contains(name));
    if (match != null) return match;

    // 4. התאמה הפוכה - השם בהגדרות מכיל את השם הזמין
    match = available.firstWhereOrNull((item) => name.contains(item));
    return match;
  }
}
