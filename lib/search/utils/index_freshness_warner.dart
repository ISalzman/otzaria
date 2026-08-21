import 'package:flutter/foundation.dart';
import 'package:otzaria/core/messages/library_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

/// אזהרה לא-חוסמת על דריפט תוכן בין ספר לאינדקס החיפוש.
///
/// תוצאת חיפוש נפתחת תמיד (הזהות כבר אומתה במסלול הפתיחה); אם חתימת
/// הטקסט באינדקס אינה תואמת את תוכן הספר, מוצגת הצעה לעדכן את האינדקס —
/// בלי לחסום דבר. ההשוואה היא מול חתימת הטקסט-בלבד (`textHash`), שאינה
/// נפסלת משינויי metadata כמו הסדר הקטלוגי (issue #828).
///
/// מפת החתימות נטענת מהמנוע פעם אחת לדור אינדקס (`getBookTextFingerprints`
/// סורק את כל האינדקס — אסור להריצו פר-ספר), וכל המטמונים מתאפסים כשהדור
/// מתחלף: החלפת המנוע ב-reopen (זהות ה-Future של הספק) או ריצת אינדוקס
/// (מעברי `isIndexing`) — כך ספר שנבדק, וגם ספר שלא היה ניתן לאימות,
/// נבדקים מחדש אחרי כל בנייה.
class IndexFreshnessWarner {
  IndexFreshnessWarner._();

  static final IndexFreshnessWarner instance = IndexFreshnessWarner._();

  /// הספק שמולו רצים — מוחלף בבדיקות בספק מזויף.
  @visibleForTesting
  TantivyDataProvider Function() providerResolver = () =>
      TantivyDataProvider.instance;

  /// השוואת ספר-מול-חתימות, מוזרקת בבדיקות שאין להן DB חי לטעינת הטקסט.
  /// מסלול טעינת המפה והמטמונים נשאר אמיתי גם אז.
  @visibleForTesting
  Future<bool> Function(Book book, Map<String, BigInt> fingerprints)?
  debugBookVerifier;

  /// הצגת האזהרה, מוזרקת בבדיקות. null = UiSnack.
  @visibleForTesting
  void Function(String message)? debugNotifier;

  final Set<String> _checkedBookKeys = {};
  Future<Map<String, BigInt>>? _fingerprints;
  Future<SearchEngine>? _engineGeneration;
  ValueNotifier<bool>? _hookedIsIndexing;

  @visibleForTesting
  void resetForTesting() {
    _resetCaches();
    _hookedIsIndexing?.removeListener(_resetCaches);
    _hookedIsIndexing = null;
    _engineGeneration = null;
    providerResolver = () => TantivyDataProvider.instance;
    debugBookVerifier = null;
    debugNotifier = null;
  }

  void _resetCaches() {
    _checkedBookKeys.clear();
    _fingerprints = null;
  }

  /// בודק פעם אחת לספר (עד להתחלפות דור האינדקס) ומזהיר על אי-התאמה
  /// ודאית. לעולם אינו זורק — כשל אימות אינו מפריע לפתיחת התוצאה, ואינו
  /// נצרב כדי שהבדיקה תנוסה שוב בפתיחה הבאה.
  Future<void> warnIfContentDrifted(Book book) async {
    final provider = providerResolver();
    _hookIndexingInvalidation(provider);
    _syncEngineGeneration(provider);

    final key = IndexingRepository.buildIndexedBookFilePath(book);
    if (!_checkedBookKeys.add(key)) return;
    try {
      final fingerprints = await (_fingerprints ??= provider.engine.then(
        (engine) => engine.getBookTextFingerprints(),
      ));
      final matches = await (debugBookVerifier ?? _bookMatches)(
        book,
        fingerprints,
      );
      if (!matches) {
        (debugNotifier ?? UiSnack.show)(
          LibraryMessages.searchResultContentDrifted,
        );
      }
    } catch (error) {
      _checkedBookKeys.remove(key);
      // מפה שנכשלה בטעינה אסור שתישאר במטמון ותכשיל כל ספר עד סוף הדור.
      _fingerprints = null;
      debugPrint('אימות טריות האינדקס נכשל עבור "${book.title}": $error');
    }
  }

  /// סוף ריצת אינדוקס משנה את תוכן האינדקס; המאזין מאפס על כל מעבר, כך
  /// שגם ספר "לא ניתן לאימות" נבדק מחדש אחרי בנייה חדשה.
  void _hookIndexingInvalidation(TantivyDataProvider provider) {
    if (identical(_hookedIsIndexing, provider.isIndexing)) return;
    _hookedIsIndexing?.removeListener(_resetCaches);
    _hookedIsIndexing = provider.isIndexing..addListener(_resetCaches);
  }

  /// reopen מחליף את `provider.engine` ב-Future חדש — זהותו היא דור
  /// האינדקס: מפה שנטענה מהמנוע הקודם אינה תקפה למנוע שנפתח מחדש.
  void _syncEngineGeneration(TantivyDataProvider provider) {
    final generation = provider.engine;
    if (identical(generation, _engineGeneration)) return;
    _engineGeneration = generation;
    _resetCaches();
  }

  Future<bool> _bookMatches(Book book, Map<String, BigInt> fingerprints) =>
      IndexingRepository(
        providerResolver(),
      ).textBookContentMatchesIndex(book, fingerprints);
}
