import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/external_catalog/repository/external_catalog_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';

/// מהדורה מקבילה של הספר הפתוח, לשימוש הלחצן המובנה בסרגל העיון.
class ParallelEdition {
  final Book book;

  /// המהדורה המובנית (עמית באותה ספרייה, למשל PDF של הש"ס) — היא הפעולה
  /// הראשית של הלחצן כל עוד קיימת; מהדורות היברובוקס באות אחריה.
  final bool isCompanion;

  const ParallelEdition({required this.book, required this.isCompanion});
}

/// איתור מהדורות מקבילות לספר הפתוח — מובנות ומקומיות בלבד.
///
/// שני מקורות, ללא שום תקשורת עם שירות חיצוני (קטלוג + דיסק בלבד):
/// 1. ספר עמית בספריית אוצריא (טקסט↔PDF של אותו ספר, כמו הלחצן הישן).
/// 2. מהדורות היברובוקס מטבלת המיפוי `otzaria_hebrew_books`, מסוננות לקבצי
///    PDF שקיימים בפועל בתיקיית ההיברובוקס שהמשתמש הגדיר.
class ParallelEditionsService {
  ParallelEditionsService._();

  /// מחזיר את המהדורות בסדר תצוגה: המובנית ראשונה (כשקיימת), ואז
  /// מהדורות היברובוקס לפי איכות ההתאמה. רשימה ריקה = אין לחצן.
  static Future<List<ParallelEdition>> find(Book current) async {
    final editions = <ParallelEdition>[];

    final companionType = current is PdfBook ? TextBook : PdfBook;
    final library = await DataRepository.instance.library;
    final companion = library.getCompanionBook(current, companionType);
    if (companion != null) {
      editions.add(ParallelEdition(book: companion, isCompanion: true));
    }

    for (final book in await _localHebrewBooksEditions(current)) {
      editions.add(ParallelEdition(book: book, isCompanion: false));
    }
    return editions;
  }

  static Future<List<Book>> _localHebrewBooksEditions(Book current) async {
    final catalog = ExternalCatalogRepository.instance;
    final external = PluginBookIdentity.externalOf(current);
    final currentHbId = external?.provider == 'hebrewbooks'
        ? PluginBookIdentity.parseId(external?.id)
        : null;

    List<int> hbIds;
    if (currentHbId != null) {
      // ספר היברובוקס פתוח: מהדורות מקבילות הן ספרי היברובוקס אחרים
      // הממופים לאותם ספרי אוצריא.
      final otzariaIds = await catalog.getOtzariaIdsForHebrewBookId(
        currentHbId,
      );
      final siblingIds = <int>{};
      for (final otzariaId in otzariaIds) {
        siblingIds.addAll(await catalog.getHebrewBookIdsForOtzariaId(otzariaId));
      }
      siblingIds.remove(currentHbId);
      hbIds = siblingIds.toList();
    } else {
      final otzariaId = current.id;
      if (otzariaId == null) return const [];
      hbIds = await catalog.getHebrewBookIdsForOtzariaId(otzariaId);
    }
    if (hbIds.isEmpty) return const [];

    // רק מהדורות שקובץ ה-PDF שלהן קיים בתיקייה שהוגדרה; בלי תיקייה — כלום.
    final probed = await FileSystemData.probeHebrewBooksPdfFilesByIds(
      hbIds.toSet(),
    );
    if (probed.isEmpty) return const [];
    final catalogBooks = await catalog.getHebrewBooksByIds(hbIds);
    final byId = {
      for (final book in FileSystemData.mapHebrewBooksToLocal(
        catalogBooks,
        probed,
      ).whereType<PdfBook>())
        book.id: book,
    };
    // שימור סדר איכות ההתאמה של המיפוי.
    return [for (final id in hbIds) ?byId[id]];
  }
}
