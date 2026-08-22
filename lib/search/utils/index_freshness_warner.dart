import 'dart:io';

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
/// החתימה נקראת פר-ספר (`getBookTextFingerprint` — TermQuery על filePath),
/// ולא כמפת קורפוס מלאה: בדיקה של ספר אחד אינה משלמת O(כל המסמכים).
class IndexFreshnessWarner {
  IndexFreshnessWarner._();

  static final IndexFreshnessWarner instance = IndexFreshnessWarner._();

  /// הספק שמולו רצים — מוחלף בבדיקות בספק מזויף.
  @visibleForTesting
  TantivyDataProvider Function() providerResolver = () =>
      TantivyDataProvider.instance;

  /// השוואת ספר-מול-חתימה, מוזרקת בבדיקות שאין להן DB חי לטעינת הטקסט.
  /// מסלול קריאת החתימה, ה-revision והמטמון נשאר אמיתי גם אז.
  @visibleForTesting
  Future<bool> Function(Book book, BigInt indexHash)? debugBookVerifier;

  /// הצגת האזהרה, מוזרקת בבדיקות. null = UiSnack.
  @visibleForTesting
  void Function(String message)? debugNotifier;

  /// המפתח באינדקס → ה-revision של המקור בזמן הבדיקה המוצלחת האחרונה.
  final Map<String, String> _checkedRevisionByKey = {};
  ValueNotifier<bool>? _hookedIsIndexing;
  Future<SearchEngine>? _engineGeneration;
  Future<Library>? _libraryGeneration;

  @visibleForTesting
  void resetForTesting() {
    _checkedRevisionByKey.clear();
    _hookedIsIndexing?.removeListener(_invalidate);
    _hookedIsIndexing = null;
    _engineGeneration = null;
    _libraryGeneration = null;
    providerResolver = () => TantivyDataProvider.instance;
    debugBookVerifier = null;
    debugNotifier = null;
  }

  void _invalidate() => _checkedRevisionByKey.clear();

  /// reopen מחליף את `provider.engine`, ורענון ספרייה את
  /// `DataRepository.instance.library` — התחלפות של אחד מהם פוסלת את כל
  /// מה שנבדק מול הדור הקודם.
  void _invalidateOnGenerationChange(
    Future<SearchEngine> engineGeneration,
    Future<Library> libraryGeneration,
  ) {
    if (identical(engineGeneration, _engineGeneration) &&
        identical(libraryGeneration, _libraryGeneration)) {
      return;
    }
    _engineGeneration = engineGeneration;
    _libraryGeneration = libraryGeneration;
    _invalidate();
  }

  /// בודק ספר פעם אחת לכל שילוב של מפתח-אינדקס ו-revision של המקור,
  /// ומזהיר על אי-התאמה ודאית. לעולם אינו זורק — כשל אימות אינו מפריע
  /// לפתיחת התוצאה, ואינו נצרב כדי שהבדיקה תנוסה שוב בפתיחה הבאה.
  Future<void> warnIfContentDrifted(Book book) async {
    final provider = providerResolver();
    _hookIndexingInvalidation(provider);

    // צילום זהויות הדור *לפני* כל await: אינדקס שנפתח מחדש או ספרייה
    // שהתרעננה בזמן ההמתנה הופכים את התוצאה הזו ללא-רלוונטית, גם אם שום
    // בדיקה אחרת לא נכנסה בינתיים כדי להבחין בכך.
    final engineGeneration = provider.engine;
    final libraryGeneration = DataRepository.instance.library;
    _invalidateOnGenerationChange(engineGeneration, libraryGeneration);

    final key = IndexingRepository.buildIndexedBookFilePath(book);
    try {
      // ה-revision מזהה שינוי בקובץ המקור עצמו: ספר file-backed נקרא
      // ישירות מהדיסק, ואין רענון ספרייה שיסמן עריכה חיצונית שלו.
      final revision = await _sourceRevision(book);
      if (_checkedRevisionByKey[key] == revision) return;

      final engine = await engineGeneration;
      final indexHash = await engine.getBookTextFingerprint(filePath: key);
      final matches = await (debugBookVerifier ?? _bookMatches)(
        book,
        indexHash,
      );

      // אין await בין הבדיקה הזו לבין ההצגה/הכתיבה למטמון.
      if (!_generationsUnchanged(
        provider,
        engineGeneration,
        libraryGeneration,
      )) {
        return;
      }
      _checkedRevisionByKey[key] = revision;
      if (!matches) {
        (debugNotifier ?? UiSnack.show)(
          LibraryMessages.searchResultContentDrifted,
        );
      }
    } catch (error) {
      debugPrint('אימות טריות האינדקס נכשל עבור "${book.title}": $error');
    }
  }

  /// חתימת המקור של הספר: נתיב + זמן שינוי + גודל, כשיש קובץ מקור.
  /// מחרוזת ריקה לספר שכל תוכנו ב-DB — שינוי בו מגיע דרך רענון ספרייה,
  /// שממילא מאפס את המטמון.
  Future<String> _sourceRevision(Book book) async {
    final path = book is TextBook
        ? book.filePath
        : (book is FileBook ? book.path : null);
    if (path == null || path.isEmpty) return '';
    try {
      final stat = await File(path).stat();
      if (stat.type == FileSystemEntityType.notFound) return '';
      return '$path|${stat.modified.millisecondsSinceEpoch}|${stat.size}';
    } on FileSystemException {
      return '';
    }
  }

  bool _generationsUnchanged(
    TantivyDataProvider provider,
    Future<SearchEngine> engineGeneration,
    Future<Library> libraryGeneration,
  ) =>
      identical(provider.engine, engineGeneration) &&
      identical(DataRepository.instance.library, libraryGeneration);

  /// סוף ריצת אינדוקס משנה את תוכן האינדקס; המאזין מאפס על כל מעבר, כך
  /// שגם ספר "לא ניתן לאימות" נבדק מחדש אחרי בנייה חדשה.
  void _hookIndexingInvalidation(TantivyDataProvider provider) {
    if (identical(_hookedIsIndexing, provider.isIndexing)) return;
    _hookedIsIndexing?.removeListener(_invalidate);
    _hookedIsIndexing = provider.isIndexing..addListener(_invalidate);
  }

  Future<bool> _bookMatches(Book book, BigInt indexHash) => IndexingRepository(
    providerResolver(),
  ).textBookContentMatchesIndex(book, indexHash);
}
