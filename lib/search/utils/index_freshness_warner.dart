import 'package:flutter/foundation.dart';
import 'package:otzaria/core/messages/library_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

/// אזהרה לא-חוסמת על דריפט תוכן בין ספר לאינדקס החיפוש.
///
/// תוצאת חיפוש נפתחת תמיד (הזהות כבר אומתה במסלול הפתיחה); אם חתימת
/// הטקסט באינדקס אינה תואמת את תוכן הספר, מוצגת הצעה לעדכן את האינדקס —
/// בלי לחסום דבר. ההשוואה היא מול חתימת הטקסט-בלבד (`textHash`), שאינה
/// נפסלת משינויי metadata כמו הסדר הקטלוגי (issue #828).
///
/// מפת החתימות נטענת מהמנוע פעם אחת לדור (`getBookTextFingerprints`
/// סורק את כל האינדקס — אסור להריצו פר-ספר), וכל המטמונים מתאפסים
/// כשמתחלף דור של אחד משני הצדדים שההשוואה תלויה בהם:
/// * **האינדקס** — החלפת המנוע ב-reopen (זהות ה-Future של הספק) או ריצת
///   אינדוקס (מעברי `isIndexing`).
/// * **הספרייה** — כל רענון מחליף את `DataRepository.instance.library`
///   ב-Future חדש, גם כשעדכון אינדקס אוטומטי כבוי ושום אות אינדקס לא
///   נורה; בלעדיו ספר שנערך היה מדולג לנצח.
///
/// כל איפוס מקדם epoch; בדיקה שנפתחה תחת epoch ישן אינה מציגה אזהרה
/// ואינה נוגעת במטמונים — התוצאה שלה שייכת לדור שכבר איננו.
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
  Future<Library>? _libraryGeneration;
  ValueNotifier<bool>? _hookedIsIndexing;
  int _epoch = 0;

  @visibleForTesting
  void resetForTesting() {
    _resetCaches();
    _hookedIsIndexing?.removeListener(_resetCaches);
    _hookedIsIndexing = null;
    _engineGeneration = null;
    _libraryGeneration = null;
    providerResolver = () => TantivyDataProvider.instance;
    debugBookVerifier = null;
    debugNotifier = null;
  }

  void _resetCaches() {
    _epoch++;
    _checkedBookKeys.clear();
    _fingerprints = null;
  }

  /// בודק פעם אחת לספר (עד להתחלפות דור) ומזהיר על אי-התאמה ודאית.
  /// לעולם אינו זורק — כשל אימות אינו מפריע לפתיחת התוצאה, ואינו נצרב
  /// כדי שהבדיקה תנוסה שוב בפתיחה הבאה.
  Future<void> warnIfContentDrifted(Book book) async {
    final provider = providerResolver();
    _hookIndexingInvalidation(provider);
    _syncGenerations(provider);

    final key = IndexingRepository.buildIndexedBookFilePath(book);
    if (!_checkedBookKeys.add(key)) return;
    final epoch = _epoch;
    try {
      final fingerprints = await (_fingerprints ??= provider.engine.then(
        (engine) => engine.getBookTextFingerprints(),
      ));
      final matches = await (debugBookVerifier ?? _bookMatches)(
        book,
        fingerprints,
      );
      // הדור התחלף בזמן ההמתנה — התוצאה שייכת למפה/לתוכן שכבר אינם.
      if (epoch != _epoch) return;
      if (!matches) {
        (debugNotifier ?? UiSnack.show)(
          LibraryMessages.searchResultContentDrifted,
        );
      }
    } catch (error) {
      // אחרי איפוס אסור לגעת במטמונים של הדור החדש (הסרת key שנוסף בו,
      // או מחיקת מפה טרייה) — הניקוי שייך רק לדור שבו הבדיקה התחילה.
      if (epoch == _epoch) {
        _checkedBookKeys.remove(key);
        _fingerprints = null;
      }
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

  /// שני צדי ההשוואה הם דורות: reopen מחליף את `provider.engine`, ורענון
  /// ספרייה מחליף את `DataRepository.instance.library` — גם בלי שום
  /// ריצת אינדוקס (עדכון אינדקס אוטומטי כבוי, עריכת ספר אישי).
  void _syncGenerations(TantivyDataProvider provider) {
    final engineGeneration = provider.engine;
    final libraryGeneration = DataRepository.instance.library;
    if (identical(engineGeneration, _engineGeneration) &&
        identical(libraryGeneration, _libraryGeneration)) {
      return;
    }
    _engineGeneration = engineGeneration;
    _libraryGeneration = libraryGeneration;
    _resetCaches();
  }

  Future<bool> _bookMatches(Book book, Map<String, BigInt> fingerprints) =>
      IndexingRepository(
        providerResolver(),
      ).textBookContentMatchesIndex(book, fingerprints);
}
