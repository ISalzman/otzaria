import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/data/data_providers/user_books_database_holder.dart';
import 'package:otzaria/migration/database/repository/seforim_repository.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/indexing/services/indexing_isolate_service.dart';
import 'package:otzaria/search/book_facet.dart';
import 'package:otzaria/search/utils/search_catalogue_order_helper.dart';
import 'package:otzaria/utils/text/ref_helper.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

class IndexingRepository {
  final TantivyDataProvider _tantivyDataProvider;
  final IndexingIsolateService? _isolateService;
  IndexingIsolateService? _activeIsolateService;

  IndexingRepository(this._tantivyDataProvider,
      {IndexingIsolateService? isolateService})
      : _isolateService = isolateService;

  /// בודקת אם בכלל יש טעם להריץ את בדיקת requiresManualReindex.
  /// ספרייה ריקה (כולל המקרה של "אין ספרייה") אין טעם לאפס לה אינדקס,
  /// כי אין מה לאנדקס מחדש.
  @visibleForTesting
  static bool shouldSkipManualReindexCheck(Library library) {
    return library.getAllBooks().isEmpty;
  }

  @visibleForTesting
  static bool areAllIndexableBooksIndexed(
    Iterable<Book> books,
    Set<String> indexedFilePaths,
  ) {
    final indexableBooks = books.where(isIndexableBook).toList();
    if (indexableBooks.isEmpty) {
      return false;
    }

    return indexableBooks.every(
      (book) => indexedFilePaths.contains(buildIndexedBookFilePath(book)),
    );
  }

  /// האם הספר כבר מאונדקס — לפי המסמכים החיים שנקראו מהאינדקס עצמו.
  bool isBookIndexed(Book book) => _tantivyDataProvider.indexedFilePaths
      .contains(buildIndexedBookFilePath(book));

  /// האם האינדקס הקיים דורש איפוס ובנייה מחדש, לפי בדיקת התאימות
  /// של מנוע החיפוש (נקראת מהאינדקס עצמו).
  Future<bool> requiresManualReindex(Library library) async {
    if (shouldSkipManualReindexCheck(library)) {
      return false;
    }
    await _tantivyDataProvider.engine;
    return _tantivyDataProvider.requiresManualReindex;
  }

  /// Indexes all books in the provided library.
  ///
  /// [library] The library containing books to index
  /// [onProgress] Callback function to report progress
  /// מבצע אינדוקס ומחזיר true אם הסתיים בהצלחה, false אם בוטל
  Future<bool> indexAllBooks(
    Library library, {
    void Function()? onActualIndexingStarted,
    required void Function(int processed, int total) onProgress,
  }) async {
    final allBooks = library.getAllBooks();
    final totalBooks = allBooks.length;

    if (await requiresManualReindex(library)) {
      debugPrint(
        '⚠️ האינדקס דורש איפוס ובנייה מחדש באישור המשתמש - מדלג על אינדוקס אוטומטי',
      );
      return false;
    }

    if (areAllIndexableBooksIndexed(
      allBooks,
      _tantivyDataProvider.indexedFilePaths,
    )) {
      debugPrint(
        '⚡ Fast path: כל הספרים האינדקסביליים כבר מאונדקסים לפי האינדקס עצמו - מדלג על האינדוקס',
      );
      return true;
    }

    _tantivyDataProvider.isIndexing.value = true;
    IndexingIsolateService? isolateService;
    bool cancelled = false;
    var didStartActualIndexing = false;

    try {
      await _setDbReadBoost(true);

      isolateService = _isolateService ?? await IndexingIsolateService.create();
      _activeIsolateService = isolateService;
      final catalogueOrderByBookKey =
          SearchCatalogueOrderHelper.buildKeyOrderMap(
        library,
        keyOf: (book) => catalogueOrderKey(book as Book),
      );

      int processedBooks = 0;
      int actuallyIndexed = 0;
      int skipped = 0;
      int errors = 0;

      debugPrint('📚 התחלת אינדוקס: $totalBooks ספרים');
      debugPrint(
          '📊 ספרים שכבר מאונדקסים: ${_tantivyDataProvider.indexedFilePaths.length}');

      for (Book book in allBooks) {
        if (!_tantivyDataProvider.isIndexing.value) {
          debugPrint('⚠️ אינדוקס בוטל על ידי המשתמש');
          cancelled = true;
          break;
        }

        try {
          // DocxBook עובר אינדוקס דרך זרימת TextBook (העטיפה משמרת
          // id/categoryId כדי ש-`book.text` יחלץ docx → text).
          // catalogueOrderKey של DocxBook ו-TextBook העטוף זהה: כשיש id
          // המפתח הוא 'id:<id>', וכשאין — title+categoryKey+'docx'+path
          // (העטיפה מעבירה filePath ?? path, ו-fileType נשאר 'docx').
          final TextBook? textBookForIndex = book is TextBook
              ? book
              : (book is DocxBook ? book.toTextBook() : null);
          if (textBookForIndex != null) {
            if (!isBookIndexed(book)) {
              debugPrint('📖 מאנדקס ספר טקסט במנוע: ${book.title}');
              await _indexTextBook(
                textBookForIndex,
                catalogueOrderByBookKey: catalogueOrderByBookKey,
                onActualIndexingStarted: () {
                  if (didStartActualIndexing) {
                    return;
                  }
                  didStartActualIndexing = true;
                  onActualIndexingStarted?.call();
                },
              );
              if (!_tantivyDataProvider.isIndexing.value) {
                cancelled = true;
                break;
              }
              _tantivyDataProvider.indexedFilePaths
                  .add(buildIndexedBookFilePath(book));
              actuallyIndexed++;
            } else {
              debugPrint('⏭️ דילוג על ספר טקסט שכבר מאונדקס: ${book.title}');
              skipped++;
            }
          } else if (book is PdfBook) {
            if (!isBookIndexed(book)) {
              debugPrint('📄 מאנדקס PDF ב-isolate: ${book.title}');
              await _indexPdfBook(
                book,
                isolateService,
                catalogueOrderByBookKey: catalogueOrderByBookKey,
                onActualIndexingStarted: () {
                  if (didStartActualIndexing) {
                    return;
                  }
                  didStartActualIndexing = true;
                  onActualIndexingStarted?.call();
                },
              );
              if (!_tantivyDataProvider.isIndexing.value) {
                cancelled = true;
                break;
              }
              _tantivyDataProvider.indexedFilePaths
                  .add(buildIndexedBookFilePath(book));
              actuallyIndexed++;
            } else {
              debugPrint('⏭️ דילוג על PDF שכבר מאונדקס: ${book.title}');
              skipped++;
            }
          }

          processedBooks++;
          if (processedBooks % 25 == 0) {
            debugPrint('💾 שומר אינדקס (commit)...');
            final index = await _tantivyDataProvider.engine;
            await index.commit();
          }

          if (processedBooks % 50 == 0) {
            debugPrint(
                '📈 התקדמות: $processedBooks/$totalBooks (מאונדקסים: $actuallyIndexed, דולגו: $skipped, שגיאות: $errors)');
          }

          onProgress(processedBooks, totalBooks);
        } catch (e) {
          await Future.microtask(() {
            debugPrint('❌ שגיאה באינדוקס של ${book.title}: $e');
          });
          errors++;
          processedBooks++;
          onProgress(processedBooks, totalBooks);
          await Future.delayed(Duration.zero);
        }

        await Future.delayed(Duration.zero);
      }

      if (!cancelled) {
        debugPrint('✅ אינדוקס הושלם!');
        debugPrint('   📊 סה"כ: $totalBooks ספרים');
        debugPrint('   ✅ מאונדקסים: $actuallyIndexed');
        debugPrint('   ⏭️ דולגו: $skipped');
        debugPrint('   ❌ שגיאות: $errors');

        debugPrint('💾 שומר אינדקס סופי (final commit)...');
        final index = await _tantivyDataProvider.engine;
        await index.commit();
        debugPrint('⚙️ מבצע optimize לאינדקס...');
        await optimizeIndexBestEffort(index.optimize);
        debugPrint('✅ אינדקס נשמר בהצלחה!');
      }
    } finally {
      await _setDbReadBoost(false);
      _activeIsolateService = null;
      if (isolateService != null &&
          !identical(isolateService, _isolateService)) {
        await isolateService.dispose();
      }
      _tantivyDataProvider.isIndexing.value = false;
    }
    return !cancelled;
  }

  Future<void> _indexTextBook(
    TextBook book, {
    required Map<String, int> catalogueOrderByBookKey,
    String? preloadedText,
    void Function()? onActualIndexingStarted,
  }) async {
    final text = await _loadTextBookText(book, preloadedText: preloadedText);
    var wroteDocuments = false;

    if (text != null) {
      // כל הכנת הספר — פיצול לשורות, מעקב reference trail, נרמול, טביעת
      // אצבע ואינדוקס — רצה במנוע בקריאת FFI אחת: הטקסט חוצה את הגשר פעם
      // אחת בלבד, במקום המסלול הישן (isolate ‏← נרמול באצוות ‏← העתקת
      // SendPort ‏← addDocumentsBatch) שהעתיק את תוכן הספר ארבע-חמש פעמים.
      // הביטול נבדק לפני הקריאה; בתוך ספר בודד הכתיבה אטומית מבחינתנו.
      onActualIndexingStarted?.call();
      if (!_tantivyDataProvider.isIndexing.value) {
        return;
      }
      final engine = await _tantivyDataProvider.engine;
      final added = await engine.addTextBook(
        title: book.title,
        topics: _bookTopics(book),
        filePath: buildIndexedBookFilePath(book),
        catalogueOrder:
            catalogueOrderByBookKey[catalogueOrderKey(book)] ?? 0xFFFFFFFF,
        text: text,
      );
      wroteDocuments = added > 0;
    }

    if (!wroteDocuments) {
      // text == null ⇒ אין טביעת אצבע; במסלול המלא המנוע חותם אותה בעצמו.
      await _writeEmptyBookMarker(
        book,
        catalogueOrderByBookKey: catalogueOrderByBookKey,
      );
    }
  }

  Future<void> _indexPdfBook(
    PdfBook book,
    IndexingIsolateService isolateService, {
    required Map<String, int> catalogueOrderByBookKey,
    void Function()? onActualIndexingStarted,
  }) async {
    final pages = await _extractPdfPages(book);
    var wroteDocuments = false;

    if (pages.isNotEmpty) {
      final stream = await isolateService.processPdfPages(pages: pages);
      wroteDocuments = await _consumePreparedDocuments(
        book: book,
        stream: stream,
        isolateService: isolateService,
        catalogueOrderByBookKey: catalogueOrderByBookKey,
        onActualIndexingStarted: onActualIndexingStarted,
      );
    }

    if (!wroteDocuments) {
      await _writeEmptyBookMarker(
        book,
        catalogueOrderByBookKey: catalogueOrderByBookKey,
      );
    }
  }

  /// רושם באינדקס מסמך ריק יחיד עבור ספר שלא הניב תוכן לאינדוקס (למשל PDF
  /// סרוק ללא שכבת טקסט). מסמך ריק לעולם לא עולה בתוצאות חיפוש, אבל הוא
  /// גורם לאינדקס עצמו לזכור שהספר כבר עובד — כך הוא לא יעובד מחדש בכל
  /// הפעלה. בלי זה, מצב האינדוקס (שנקרא מהאינדקס) לעולם לא היה שלם.
  Future<void> _writeEmptyBookMarker(
    Book book, {
    required Map<String, int> catalogueOrderByBookKey,
    BigInt? contentHash,
  }) async {
    if (!_tantivyDataProvider.isIndexing.value) {
      return;
    }
    await _writePreparedBatch(
      book,
      const [
        PreparedIndexDocument(reference: '', text: '', segment: 0, ordinal: 0),
      ],
      catalogueOrderByBookKey: catalogueOrderByBookKey,
      contentHash: contentHash,
    );
  }

  bool _hasUsablePdfText(
      List<({String reference, String text, int pageIndex})> pages) {
    for (final page in pages) {
      // קריאת FFI אחת לעמוד (נרמול + סינון זבל באצווה) במקום שתיים לכל שורה.
      final prepared = IndexingDocumentBuilder.normalizePdfTextsForIndexing(
        page.text.split('\n'),
      );
      if (prepared.any((line) => !line.isGarbage)) {
        return true;
      }
    }
    return false;
  }

  Future<List<({String reference, String text, int pageIndex})>>
      _extractPdfPages(PdfBook book) async {
    final file = File(book.path);
    if (!await file.exists()) return const [];

    List<PdfOutlineNode> outline = const [];

    try {
      final document = await PdfDocument.openFile(book.path)
          .timeout(const Duration(seconds: 60));
      outline = await document.loadOutline().timeout(
            const Duration(seconds: 15),
            onTimeout: () => <PdfOutlineNode>[],
          );

      final pages = <({String reference, String text, int pageIndex})>[];

      for (int i = 0; i < document.pages.length; i++) {
        if (!_tantivyDataProvider.isIndexing.value) return const [];

        final pageText = await document.pages[i].loadText().timeout(
              const Duration(seconds: 5),
              onTimeout: () => null,
            );
        if (pageText == null) continue;

        final bookmark = await refFromPageNumber(i + 1, outline, book.title);
        final ref = bookmark.isNotEmpty
            ? '${book.title}, $bookmark, עמוד ${i + 1}'
            : '${book.title}, עמוד ${i + 1}';

        pages.add((reference: ref, text: pageText.fullText, pageIndex: i));
      }

      // Don't call document.dispose() explicitly - pdfrx's background page
      // preloader may still be executing FFI callbacks at this point.
      // Let the GC collect the document instead.

      if (_hasUsablePdfText(pages)) return pages;
    } catch (e) {
      debugPrint('❌ שגיאה בפתיחת PDF לאינדוקס: ${book.title}: $e');
      // כשל בטעינת ה-PDF עצמו (להבדיל מטקסט סרוק): בלי sidecar מפיצים את
      // השגיאה, אחרת הספר היה נרשם כ"ריק" לצמיתות ולא מנוסה שוב.
      final sidecarPages = await _loadPdfSidecar(book, outline);
      if (sidecarPages.isEmpty) rethrow;
      return sidecarPages;
    }

    return _loadPdfSidecar(book, outline);
  }

  Future<List<({String reference, String text, int pageIndex})>>
      _loadPdfSidecar(PdfBook book, List<PdfOutlineNode> outline) async {
    final candidates = <String>{
      '${book.path}.txt',
      p.setExtension(book.path, '.txt'),
    };

    File? sidecar;
    for (final candidate in candidates) {
      final f = File(candidate);
      if (await f.exists()) {
        sidecar = f;
        break;
      }
    }

    if (sidecar == null) return const [];

    final ocrText = await sidecar.readAsString();
    final pagesText =
        ocrText.contains('\f') ? ocrText.split('\f') : <String>[ocrText];

    final pages = <({String reference, String text, int pageIndex})>[];
    for (int pageIndex = 0; pageIndex < pagesText.length; pageIndex++) {
      final bookmark =
          await refFromPageNumber(pageIndex + 1, outline, book.title);
      final ref = bookmark.isNotEmpty
          ? '${book.title}, $bookmark, עמוד ${pageIndex + 1}'
          : '${book.title}, עמוד ${pageIndex + 1}';
      pages.add(
          (reference: ref, text: pagesText[pageIndex], pageIndex: pageIndex));
    }
    return pages;
  }

  Future<String?> _loadTextBookText(
    TextBook book, {
    String? preloadedText,
  }) async {
    String? text = preloadedText;

    if ((text == null || text.isEmpty) && book.categoryId != null) {
      debugPrint(
          '   🔍 מנסה לקרוא מ-DB: ${book.title} (categoryId: ${book.categoryId})');
      text = await SqliteDataProvider.instance.getBookTextFromDb(
        book.title,
        book.categoryId,
        book.fileType ?? 'txt',
      );
    }

    if (text == null || text.isEmpty) {
      debugPrint('   🔍 מנסה לקרוא דרך LibraryProvider: ${book.title}');
      text = await book.text;
    }

    if (text.isEmpty) {
      debugPrint(
          '⚠️ ספר ריק: ${book.title} (categoryId: ${book.categoryId}) - מדלג');
      return null;
    }

    return text;
  }

  /// מחזירה האם נכתב לאינדקס לפחות מסמך אחד עבור הספר.
  Future<bool> _consumePreparedDocuments({
    required Book book,
    required Stream<IndexingIsolateUpdate> stream,
    required IndexingIsolateService isolateService,
    required Map<String, int> catalogueOrderByBookKey,
    BigInt? contentHash,
    void Function()? onActualIndexingStarted,
  }) async {
    var wroteDocuments = false;
    try {
      await for (final update in stream) {
        if (!_tantivyDataProvider.isIndexing.value) {
          await isolateService.cancelActiveWork();
          return wroteDocuments;
        }

        if (update is! IndexingBatchReady) {
          continue;
        }

        await _writePreparedBatch(
          book,
          update.documents,
          catalogueOrderByBookKey: catalogueOrderByBookKey,
          contentHash: contentHash,
          onActualIndexingStarted: onActualIndexingStarted,
        );
        wroteDocuments = wroteDocuments || update.documents.isNotEmpty;
        await update.acknowledge();
      }
    } catch (e) {
      await isolateService.cancelActiveWork();
      rethrow;
    }
    return wroteDocuments;
  }

  /// נתיב ה-facet של הספר — משותף לכתיבת אצוות (PDF/סמן-ריק) ולמסלול
  /// ה-addTextBook המלא, כדי ששני המסלולים לא יסטו זה מזה.
  String _bookTopics(Book book) => BookFacet.buildFacetPath(
        title: book.title,
        topics: book.topics,
        externalLibraryId: book.externalLibraryId,
        bookId: book.id,
        isUserBook: book.isUserBook,
        categoryPath: book.category?.path ?? book.categoryPath,
        fileType: book.fileType,
        filePath: book is FileBook ? book.path : book.filePath,
      );

  Future<void> _writePreparedBatch(
    Book book,
    List<PreparedIndexDocument> documents, {
    required Map<String, int> catalogueOrderByBookKey,
    BigInt? contentHash,
    void Function()? onActualIndexingStarted,
  }) async {
    if (documents.isEmpty) {
      return;
    }

    onActualIndexingStarted?.call();

    if (!_tantivyDataProvider.isIndexing.value) {
      return;
    }

    final index = await _tantivyDataProvider.engine;
    final title = book.title;
    final topics = _bookTopics(book);
    final isPdf = book is PdfBook;
    final filePath = buildIndexedBookFilePath(book);
    final catalogueOrder =
        catalogueOrderByBookKey[catalogueOrderKey(book)] ?? 0xFFFFFFFF;

    // בניית רשימת מסמכים בקריאת FFI אחת
    final docs = [
      for (final document in documents)
        DocumentInput(
          id: buildCatalogueDocumentId(
            catalogueOrder: catalogueOrder,
            ordinal: document.ordinal,
          ),
          title: title,
          reference: document.reference,
          topics: topics,
          text: document.text,
          segment: BigInt.from(document.segment),
          isPdf: isPdf,
          filePath: filePath,
          contentHash: contentHash,
        ),
    ];

    // אינדוקס בלבד: כל מסלולי הכתיבה מדלגים על ספר שכבר מאונדקס
    // (isBookIndexed), כך שהספר כאן תמיד חדש ואין מה למחוק. שימוש ב-add
    // (ללא delete_term לכל מסמך) חוסך מיליוני מחיקות מיותרות שמאטות
    // דרמטית את ה-commit במנוע החיפוש.
    await index.addDocumentsBatch(docs: docs);
  }

  @visibleForTesting
  static Future<bool> optimizeIndexBestEffort(
    Future<void> Function() optimize, {
    void Function(Object error, StackTrace stackTrace)? onFailure,
  }) async {
    try {
      await optimize();
      return true;
    } catch (error, stackTrace) {
      if (onFailure != null) {
        onFailure(error, stackTrace);
      } else {
        debugPrint('⚠️ optimize נכשל אחרי commit; האינדקס כבר נשמר: $error');
        debugPrintStack(
          label: 'optimize failed after final commit',
          stackTrace: stackTrace,
        );
      }
      return false;
    }
  }

  @visibleForTesting
  static BigInt buildCatalogueDocumentId({
    required int catalogueOrder,
    required int ordinal,
  }) {
    return (BigInt.from(catalogueOrder + 1) << 32) + BigInt.from(ordinal + 1);
  }

  static int catalogueOrderFromDocumentId(BigInt documentId) {
    final encodedCatalogueOrder = (documentId >> 32).toInt();
    if (encodedCatalogueOrder <= 0) {
      return -1;
    }
    return encodedCatalogueOrder - 1;
  }

  static String catalogueOrderKey(Book book) {
    if (book.externalLibraryId != null && book.externalLibraryId!.isNotEmpty) {
      return 'ext:${book.externalLibraryId}';
    }

    if (book.id != null) {
      // id טבעי חופף בין seforim.db ל-user_books.db — בלי תיוג המקור
      // ספר אישי 'id:5' מתנגש בספר רשמי 'id:5' ומדולג באינדוקס.
      return book.isUserBook
          ? userBookKey(book.id!)
          : officialBookKey(book.id!);
    }

    final categoryKey = book.category?.path ?? book.categoryPath ?? '';
    final fileTypeKey = book.fileType ?? book.runtimeType.toString();
    final pathKey = book is FileBook ? book.path : (book.filePath ?? '');
    return '${book.title}|$categoryKey|$fileTypeKey|$pathKey';
  }

  /// מפתח catalogueOrderKey לספר אישי (user_books.db) לפי id גולמי.
  static String userBookKey(int id) => 'uid:$id';

  /// מפתח catalogueOrderKey לספר רשמי (seforim.db) לפי id גולמי.
  static String officialBookKey(int id) => 'id:$id';

  static String buildIndexedBookFilePath(Book book) {
    if (book is PdfBook) {
      return book.path;
    }
    return catalogueOrderKey(book);
  }

  /// האם רשומת הספר באינדקס מאוחסנת לפי נתיב מוחלט (ולכן תישבר בהעברת
  /// הספרייה ותדרוש ניקוי). PDF תמיד; שאר ספרי הקובץ רק כשאין להם
  /// id/externalLibraryId יציב — אחרת הם מאונדקסים לפי מפתח id ושורדים העברה.
  static bool hasPathKeyedIndexEntry(Book book) {
    if (book is PdfBook) return true;
    if (book is! FileBook) return false;
    return book.id == null &&
        (book.externalLibraryId == null || book.externalLibraryId!.isEmpty);
  }

  /// Indexes a specific list of books (e.g. newly added personal books).
  ///
  /// מבצע אינדוקס ומחזיר true אם הסתיים בהצלחה, false אם בוטל
  Future<bool> indexBooks(
    List<Book> books,
    Library library, {
    void Function()? onActualIndexingStarted,
    required void Function(int processed, int total) onProgress,
  }) async {
    if (books.isEmpty) return true;

    _tantivyDataProvider.isIndexing.value = true;
    final isolateService =
        _isolateService ?? await IndexingIsolateService.create();
    _activeIsolateService = isolateService;

    if (await requiresManualReindex(library)) {
      _tantivyDataProvider.isIndexing.value = false;
      return false;
    }

    // בנה מפת סדר קטלוג מהספרייה הטרייה שהועברה כפרמטר
    // חשוב: משתמשים בספרייה המלאה כדי שהסדר הגלובלי יהיה נכון לכל הספרים
    final catalogueOrderByBookKey = SearchCatalogueOrderHelper.buildKeyOrderMap(
      library,
      keyOf: (book) => catalogueOrderKey(book as Book),
    );

    final totalBooks = books.length;
    int processedBooks = 0;
    int actuallyIndexed = 0;
    int errors = 0;
    bool cancelled = false;
    var didStartActualIndexing = false;

    try {
      await _setDbReadBoost(true);
      for (final book in books) {
        if (!_tantivyDataProvider.isIndexing.value) {
          cancelled = true;
          break;
        }

        try {
          // DocxBook ממופה ל-TextBook (ראה הסבר ב-indexAllBooks).
          final TextBook? textBookForIndex = book is TextBook
              ? book
              : (book is DocxBook ? book.toTextBook() : null);
          if (textBookForIndex != null) {
            if (!isBookIndexed(book)) {
              debugPrint('📖 מאנדקס ספר טקסט חדש: ${book.title}');
              await _indexTextBook(
                textBookForIndex,
                catalogueOrderByBookKey: catalogueOrderByBookKey,
                onActualIndexingStarted: () {
                  if (didStartActualIndexing) return;
                  didStartActualIndexing = true;
                  onActualIndexingStarted?.call();
                },
              );
              if (!_tantivyDataProvider.isIndexing.value) {
                cancelled = true;
                break;
              }
              _tantivyDataProvider.indexedFilePaths
                  .add(buildIndexedBookFilePath(book));
              actuallyIndexed++;
            }
          } else if (book is PdfBook) {
            if (!isBookIndexed(book)) {
              debugPrint('📄 מאנדקס PDF חדש: ${book.title}');
              await _indexPdfBook(
                book,
                isolateService,
                catalogueOrderByBookKey: catalogueOrderByBookKey,
                onActualIndexingStarted: () {
                  if (didStartActualIndexing) return;
                  didStartActualIndexing = true;
                  onActualIndexingStarted?.call();
                },
              );
              if (!_tantivyDataProvider.isIndexing.value) {
                cancelled = true;
                break;
              }
              _tantivyDataProvider.indexedFilePaths
                  .add(buildIndexedBookFilePath(book));
              actuallyIndexed++;
            }
          }

          processedBooks++;
          onProgress(processedBooks, totalBooks);
        } catch (e) {
          debugPrint('❌ שגיאה באינדוקס של ${book.title}: $e');
          errors++;
          processedBooks++;
          onProgress(processedBooks, totalBooks);
        }

        await Future.delayed(Duration.zero);
      }

      if (!cancelled) {
        debugPrint(
            '✅ אינדוקס ספרים ספציפיים הושלם! (מאונדקסים: $actuallyIndexed, שגיאות: $errors)');
        final index = await _tantivyDataProvider.engine;
        await index.commit();
      }
    } finally {
      await _setDbReadBoost(false);
      _activeIsolateService = null;
      if (!identical(isolateService, _isolateService)) {
        await isolateService.dispose();
      }
      _tantivyDataProvider.isIndexing.value = false;
    }
    return !cancelled;
  }

  /// מפעיל/מכבה בוסט זמני לחיבורי הקריאה של ה-DB לטובת הקריאות הרציפות
  /// הכבדות בזמן אינדוקס (כל שורות כל ספר נקראות ברצף). מכסה גם את seforim.db
  /// וגם את user_books.db — ספרי המשתמש נקראים מחיבור נפרד. user_books מבוסט
  /// רק אם כבר פתוח (כדי לא ליצור DB ריק); בזרימת אינדוקס הוא נפתח ממילא בעת
  /// טעינת הספרייה. כשלון אינו קריטי — האינדוקס ימשיך עם פרופיל הסרק החסכוני.
  Future<void> _setDbReadBoost(bool enabled) async {
    final repos = <SeforimRepository?>[
      SqliteDataProvider.instance.repository,
      UserBooksDatabaseHolder.instance.repositoryIfInitialized,
    ];
    for (final repo in repos) {
      if (repo == null) continue;
      try {
        if (enabled) {
          await repo.setReadBoostMode();
        } else {
          await repo.restoreReadCacheDefaults();
        }
      } catch (e) {
        debugPrint('[Indexing] DB read-boost toggle failed: $e');
      }
    }
  }

  /// Cancels the ongoing indexing process.
  void cancelIndexing() {
    _tantivyDataProvider.isIndexing.value = false;
    unawaited(_activeIsolateService?.cancelActiveWork());
  }

  /// Clears the index and resets the list of indexed books.
  Future<void> clearIndex() async {
    await _tantivyDataProvider.clear();
  }

  /// מסיר מהאינדקס את רשומות הספרים הנתונים — מחיקה מדויקת לפי מפתח
  /// ה-filePath שהמסמכים נכתבו איתו ([buildIndexedBookFilePath]), כך שספר
  /// אחר החולק את אותה כותרת אינו נפגע.
  Future<void> dropBookIndexEntries(Iterable<Book> books) async {
    final keys = <String>{
      for (final book in books) buildIndexedBookFilePath(book),
    }..remove('');
    if (keys.isEmpty) return;

    final engine = await _tantivyDataProvider.engine;
    try {
      await engine.deleteDocumentsByFilePaths(filePaths: keys.toList());
      await engine.commit();
    } catch (e) {
      // בלי commit המחיקה לא נקלטה — משאירים את המעקב המקומי כמות שהוא.
      debugPrint('⚠️ מחיקת רשומות אינדקס נכשלה: $e');
      return;
    }
    _tantivyDataProvider.indexedFilePaths.removeAll(keys);
  }

  /// מסיר מהאינדקס רשומות "יתומות" — ספרים שכבר אינם בספרייה (למשל ספר
  /// אישי שנמחק או תיקייה מותאמת שהוסרה). בלעדי זה מסמכי הספר ממשיכים
  /// לעלות בחיפוש, וגרוע מזה: מזהי המסמכים שלהם (המקודדים לפי סדר קטלוגי)
  /// עלולים להתפענח לספר אחר אחרי שהסדר השתנה.
  ///
  /// שמרני בכוונה: נוגע רק במפתחות ספרים אישיים (`uid:`) ובמפתחות
  /// נתיב-מוחלט (PDF) שהקובץ מאחוריהם כבר לא קיים בדיסק. מפתחות ספרים
  /// רשמיים (`id:`) וחיצוניים (`ext:`) לא נמחקים כאן — טעינה חלקית של
  /// הספרייה הרשמית לא תגרור מחיקת אינדקס המונית ואינדוקס-מחדש של שעות.
  ///
  /// מחזיר את מספר הספרים שהוסרו.
  Future<int> dropOrphanedIndexEntries(Library library) async {
    final books = library.getAllBooks();
    if (books.isEmpty) return 0;

    // מוודא שה-indexedFilePaths כבר נטענו מהאינדקס (חלק מאתחול המנוע).
    final engine = await _tantivyDataProvider.engine;

    final libraryKeys = <String>{
      for (final book in books) buildIndexedBookFilePath(book),
    };

    final orphans = <String>[];
    // snapshot — הלולאה מכילה await ואסור שהסט החי ישתנה תחתיה.
    for (final key in _tantivyDataProvider.indexedFilePaths.toList()) {
      if (libraryKeys.contains(key)) continue;
      if (key.startsWith('uid:')) {
        orphans.add(key);
      } else if (p.isAbsolute(key) && !await File(key).exists()) {
        orphans.add(key);
      }
    }
    if (orphans.isEmpty) return 0;

    await engine.deleteDocumentsByFilePaths(filePaths: orphans);
    await engine.commit();
    _tantivyDataProvider.indexedFilePaths.removeAll(orphans);
    debugPrint('🧹 נוקו ${orphans.length} ספרים יתומים מהאינדקס');
    return orphans.length;
  }

  /// מסיר מהאינדקס רשומות של ספרי-קובץ שנתיבם השתנה בהעברת הספרייה.
  ///
  /// רשומות אלו מאונדקסות לפי נתיב מוחלט (PDF, וספרי קובץ ללא id יציב),
  /// ולכן אחרי העברה הן מצביעות לנתיב הישן. בלי הסרתן, האינדוקס האוטומטי
  /// שלאחר הרענון מוסיף את אותם ספרים בנתיב החדש ⇒ כפילויות ותוצאות שבורות.
  Future<void> dropRelocatedFileBookEntries(
          Iterable<Book> relocatedBooks) async =>
      dropBookIndexEntries(relocatedBooks);

  /// מאנדקס מחדש ספרים שתוכנם השתנה: מסיר את רשומותיהם הישנות מהאינדקס
  /// ומאנדקס אותם מחדש דרך [indexBooks].
  ///
  /// מחזיר true אם הסתיים בהצלחה, false אם בוטל או שנדרש אינדוקס ידני מלא.
  Future<bool> reindexChangedBooks(
    List<Book> changedBooks,
    Library library, {
    void Function()? onActualIndexingStarted,
    required void Function(int processed, int total) onProgress,
  }) async {
    if (changedBooks.isEmpty) return true;
    if (await requiresManualReindex(library)) return false;

    // המחיקה מדויקת לפי מפתח ה-filePath של כל ספר, ולכן אין צורך להרחיב
    // לספרים אחרים החולקים כותרת — מאנדקסים מחדש רק את מה שבאמת השתנה.
    final booksToReindex = changedBooks.where(isIndexableBook).toList();
    if (booksToReindex.isEmpty) return true;

    await dropBookIndexEntries(booksToReindex);
    return indexBooks(
      booksToReindex,
      library,
      onActualIndexingStarted: onActualIndexingStarted,
      onProgress: onProgress,
    );
  }

  /// משווה את טביעות-האצבע שבאינדקס מול תוכן הספרייה הנוכחי ומאנדקס מחדש
  /// רק ספרים שתוכנם השתנה — מכסה מסלולים שבהם איש לא דיווח מה השתנה
  /// (למשל הורדה מלאה של הספרייה, שמחליפה את ה-DB כולו).
  ///
  /// סורק ספרי טקסט בלבד: ל-PDF אין טביעת אצבע (תוכנו לא ב-DB), והוא מכוסה
  /// ע"י זיהוי mtime/גודל בסריקת הקבצים. ספר שאינו באינדקס מדולג — מסלול
  /// הספרים החדשים (StartIndexing/IndexSpecificBooks) מטפל בו.
  ///
  /// [onScanProgress] מדווח על שלב הסריקה (קריאת ה-DB והשוואה);
  /// [onProgress] מדווח על שלב האינדוקס-מחדש של הספרים שנמצאו שונים.
  /// מחזיר true אם הסתיים (גם כשאין שינויים), false אם בוטל או שנדרש
  /// אינדוקס ידני מלא.
  ///
  /// [loadText] ו-[fingerprintOf] ניתנים להזרקה בטסטים בלבד.
  Future<bool> reconcileIndexWithLibrary(
    Library library, {
    void Function(int processed, int total)? onScanProgress,
    void Function()? onActualIndexingStarted,
    required void Function(int processed, int total) onProgress,
    @visibleForTesting Future<String?> Function(TextBook book)? loadText,
    @visibleForTesting Future<BigInt> Function(String text)? fingerprintOf,
  }) async {
    if (await requiresManualReindex(library)) return false;

    final engine = await _tantivyDataProvider.engine;
    final indexFingerprints = await engine.getBookFingerprints();

    final textLoader = loadText ?? _loadTextBookText;
    // computeContentFingerprint היא כעת קריאת FFI סינכרונית; העטיפה
    // ה-async נשמרת רק כדי לא לשבור את חתימת ההזרקה של הטסטים.
    final fingerprint = fingerprintOf ??
        ((text) async => computeContentFingerprint(text: text));

    final candidates = library
        .getAllBooks()
        .where((b) => b is TextBook || b is DocxBook)
        .toList();
    final total = candidates.length;
    final changed = <Book>[];
    var cancelled = false;

    // isIndexing משמש גם כחיווי עבודה וגם כערוץ הביטול של המשתמש —
    // בדיוק כמו במסלולי האינדוקס עצמם.
    _tantivyDataProvider.isIndexing.value = true;
    try {
      await _setDbReadBoost(true);
      var processed = 0;
      for (final book in candidates) {
        if (!_tantivyDataProvider.isIndexing.value) {
          cancelled = true;
          break;
        }
        processed++;

        final indexHash = indexFingerprints[buildIndexedBookFilePath(book)];
        if (indexHash == null) {
          // הספר אינו באינדקס — ספר חדש, לא ענייננו כאן.
          onScanProgress?.call(processed, total);
          continue;
        }

        final TextBook textBook =
            book is TextBook ? book : (book as DocxBook).toTextBook();
        final text = await textLoader(textBook);
        if (text == null) {
          // אין תוכן להשוואה (כשל טעינה) — לא נוגעים ברשומה הקיימת.
          onScanProgress?.call(processed, total);
          continue;
        }

        // hash אפס = "לא ניתן לאימות" (מסמכים סותרים / אינדוקס ישן) —
        // מאנדקסים מחדש כדי לרכוש טביעת אצבע תקינה.
        final dbHash = await fingerprint(text);
        if (indexHash == BigInt.zero || dbHash != indexHash) {
          changed.add(book);
        }

        onScanProgress?.call(processed, total);
        await Future.delayed(Duration.zero);
      }
    } finally {
      await _setDbReadBoost(false);
      _tantivyDataProvider.isIndexing.value = false;
    }

    if (cancelled) return false;
    if (changed.isEmpty) {
      debugPrint('🔎 reconcile: האינדקס תואם את הספרייה — אין מה לעדכן');
      return true;
    }

    debugPrint('🔁 reconcile: ${changed.length} ספרים השתנו — מאנדקס מחדש');
    return reindexChangedBooks(
      changed,
      library,
      onActualIndexingStarted: onActualIndexingStarted,
      onProgress: onProgress,
    );
  }

  /// Returns true for book types that the indexer actually processes.
  /// Non-indexable types (ExternalLibraryBook וכו') מדולגים בשקט
  /// ב-indexAllBooks, ולכן חייבים להיות מחוץ לבדיקות הסטטוס.
  /// DocxBook נכלל — הוא ממופה ל-TextBook ב-indexAllBooks באמצעות
  /// `DocxBook.toTextBook()`, ו-`book.text` כבר יודע לחלץ את התוכן
  /// דרך `docxToText` (ראה DatabaseLibraryProvider.getBookText).
  static bool isIndexableBook(Book book) =>
      book is TextBook || book is PdfBook || book is DocxBook;

  /// Waits until the underlying data provider is fully initialized
  /// (indexedFilePaths loaded from the index itself).
  Future<void> awaitReady() async {
    await _tantivyDataProvider.engine;
  }

  /// Checks if indexing is currently in progress.
  bool isIndexing() {
    return _tantivyDataProvider.isIndexing.value;
  }
}
