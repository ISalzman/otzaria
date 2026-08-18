import 'package:flutter/foundation.dart';
import 'package:otzaria/core/messages/library_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';
import 'package:otzaria/models/books.dart';

/// אזהרה לא-חוסמת על דריפט תוכן בין ספר לאינדקס החיפוש.
///
/// תוצאת חיפוש נפתחת תמיד (הזהות כבר אומתה במסלול הפתיחה); אם חתימת
/// הטקסט באינדקס אינה תואמת את תוכן הספר, מוצגת הצעה לעדכן את האינדקס —
/// בלי לחסום דבר. ההשוואה היא מול חתימת הטקסט-בלבד (`textHash`), שאינה
/// נפסלת משינויי metadata כמו הסדר הקטלוגי (issue #828).
class IndexFreshnessWarner {
  IndexFreshnessWarner._();

  static final IndexFreshnessWarner instance = IndexFreshnessWarner._();

  /// אימות מוזרק בבדיקות. null = אימות אמיתי מול המנוע.
  @visibleForTesting
  Future<bool> Function(Book book)? debugVerifier;

  /// הצגת האזהרה, מוזרקת בבדיקות. null = UiSnack.
  @visibleForTesting
  void Function(String message)? debugNotifier;

  final Set<String> _checkedBookKeys = {};

  @visibleForTesting
  void resetForTesting() {
    _checkedBookKeys.clear();
    debugVerifier = null;
    debugNotifier = null;
  }

  /// בודק פעם אחת לספר (לכל חיי התהליך) ומזהיר על אי-התאמה ודאית.
  /// לעולם אינו זורק — כשל אימות אינו מפריע לפתיחת התוצאה, ואינו נצרב
  /// כדי שהבדיקה תנוסה שוב בפתיחה הבאה.
  Future<void> warnIfContentDrifted(Book book) async {
    final key = IndexingRepository.buildIndexedBookFilePath(book);
    if (!_checkedBookKeys.add(key)) return;
    try {
      final matches = await (debugVerifier ?? _contentMatchesIndex)(book);
      if (!matches) {
        (debugNotifier ?? UiSnack.show)(
          LibraryMessages.searchResultContentDrifted,
        );
      }
    } catch (error) {
      _checkedBookKeys.remove(key);
      debugPrint('אימות טריות האינדקס נכשל עבור "${book.title}": $error');
    }
  }

  static Future<bool> _contentMatchesIndex(Book book) async {
    final provider = TantivyDataProvider.instance;
    final engine = await provider.engine;
    return IndexingRepository(
      provider,
    ).textBookContentMatchesIndex(book, await engine.getBookTextFingerprints());
  }
}
