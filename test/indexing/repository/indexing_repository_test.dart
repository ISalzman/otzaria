import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/indexing/repository/indexing_repository.dart';
import 'package:otzaria/indexing/services/indexing_isolate_service.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

void main() {
  group('IndexingRepository.shouldSkipManualReindexCheck', () {
    test('מחזיר true עבור ספרייה ריקה - מונע דיאלוג איפוס בלי ספרים', () {
      expect(
        IndexingRepository.shouldSkipManualReindexCheck(
          Library(categories: []),
        ),
        isTrue,
      );
    });

    test('מחזיר true עבור ספרייה עם קטגוריות ריקות', () {
      final library = Library(categories: []);
      library.subCategories.add(
        Category(
          title: 'תנ"ך',
          description: '',
          shortDescription: '',
          order: 1,
          subCategories: [],
          books: [],
          parent: library,
        ),
      );
      expect(
        IndexingRepository.shouldSkipManualReindexCheck(library),
        isTrue,
      );
    });

    test('מחזיר false עבור ספרייה עם ספר אחד', () {
      final library = _buildLibrary(bavliBooks: const [('שבת', 1)]);
      expect(
        IndexingRepository.shouldSkipManualReindexCheck(library),
        isFalse,
      );
    });
  });

  group('IndexingRepository.areAllIndexableBooksIndexed', () {
    test('מחזיר true כשכל הספרים האינדקסביליים קיימים באינדקס', () {
      final library = _buildLibrary(
        bavliBooks: const [('שבת', 1)],
        additionalBooks: [
          PdfBook(
            title: 'קובץ PDF',
            path: r'C:\library\sample.pdf',
            categoryPath: 'ספרים אישיים',
          ),
          ExternalLibraryBook(
            title: 'ספר חיצוני',
            id: 900,
            link: 'https://example.com/book',
          ),
        ],
      );

      final indexedFilePaths = library
          .getAllBooks()
          .where(IndexingRepository.isIndexableBook)
          .map(IndexingRepository.buildIndexedBookFilePath)
          .toSet();

      expect(
        IndexingRepository.areAllIndexableBooksIndexed(
          library.getAllBooks(),
          indexedFilePaths,
        ),
        isTrue,
      );
    });

    test('מחזיר false כשחסר ספר אינדקסבילי אחד', () {
      final library = _buildLibrary(
        bavliBooks: const [('שבת', 1)],
        additionalBooks: [
          DocxBook(
            title: 'מסמך',
            path: r'C:\library\doc.docx',
            categoryPath: 'ספרים אישיים',
          ),
        ],
      );

      final indexedFilePaths = {
        IndexingRepository.buildIndexedBookFilePath(
            library.getAllBooks().first),
      };

      expect(
        IndexingRepository.areAllIndexableBooksIndexed(
          library.getAllBooks(),
          indexedFilePaths,
        ),
        isFalse,
      );
    });

    test('מחזיר false כשאין כלל ספרים אינדקסביליים', () {
      final library = Library(categories: []);
      library.books.add(
        ExternalLibraryBook(
          title: 'ספר חיצוני',
          id: 901,
          link: 'https://example.com/ext',
        ),
      );

      expect(
        IndexingRepository.areAllIndexableBooksIndexed(
          library.getAllBooks(),
          const <String>{},
        ),
        isFalse,
      );
    });
  });

  group('IndexingRepository.hasPathKeyedIndexEntry', () {
    test('PdfBook תמיד מאונדקס לפי נתיב (גם עם id)', () {
      expect(
        IndexingRepository.hasPathKeyedIndexEntry(
            PdfBook(title: 'ברכות', path: r'C:\lib\ברכות.pdf')),
        isTrue,
      );
      expect(
        IndexingRepository.hasPathKeyedIndexEntry(
            PdfBook(title: 'ברכות', path: r'C:\lib\ברכות.pdf', id: 5)),
        isTrue,
      );
    });

    test('DocxBook ללא id — לפי נתיב; עם id — שורד העברה', () {
      expect(
        IndexingRepository.hasPathKeyedIndexEntry(
            DocxBook(title: 'מסמך', path: r'C:\lib\doc.docx')),
        isTrue,
      );
      expect(
        IndexingRepository.hasPathKeyedIndexEntry(
            DocxBook(title: 'מסמך', path: r'C:\lib\doc.docx', id: 7)),
        isFalse,
      );
    });

    test('TextBook מ-DB — לא לפי נתיב', () {
      expect(
        IndexingRepository.hasPathKeyedIndexEntry(TextBook(title: 'שבת')),
        isFalse,
      );
    });
  });

  group('IndexingRepository.dropRelocatedFileBookEntries', () {
    test('מוחק כל כותרת ייחודית פעם אחת ומבצע commit יחיד', () async {
      final engine = _RecordingSearchEngine();
      final repository =
          IndexingRepository(_RecordingTantivyDataProvider(engine));

      await repository.dropRelocatedFileBookEntries([
        PdfBook(title: 'ברכות', path: r'C:\old\ברכות.pdf'),
        PdfBook(title: 'ברכות', path: r'C:\old\ברכות-עותק.pdf'),
        PdfBook(title: 'שבת', path: r'C:\old\שבת.pdf'),
      ]);

      expect(engine.removedTitles.toSet(), {'ברכות', 'שבת'});
      expect(engine.commitCount, 1);
    });

    test('ללא ספרים — לא נוגע במנוע', () async {
      final engine = _RecordingSearchEngine();
      final repository =
          IndexingRepository(_RecordingTantivyDataProvider(engine));

      await repository.dropRelocatedFileBookEntries(const []);

      expect(engine.removedTitles, isEmpty);
      expect(engine.commitCount, 0);
    });
  });

  group('IndexingRepository.dropBookIndexEntries', () {
    test('מסיר גם את מפתחות הספרים מ-indexedFilePaths', () async {
      final engine = _RecordingSearchEngine();
      final provider = _RecordingTantivyDataProvider(engine);
      final book = TextBook(id: 5, title: 'שבת');
      provider.indexedFilePaths
          .add(IndexingRepository.buildIndexedBookFilePath(book));
      final repository = IndexingRepository(provider);

      await repository.dropBookIndexEntries([book]);

      expect(engine.removedTitles, ['שבת']);
      expect(provider.indexedFilePaths, isEmpty);
    });
  });

  group('IndexingRepository.reindexChangedBooks', () {
    test('מרחיב לספרים בעלי אותה כותרת, מוחק ומאנדקס מחדש רק אותם', () async {
      final engine = _RecordingSearchEngine();
      final provider = _RecordingTantivyDataProvider(engine);
      final official = TextBook(id: 5, title: 'שבת');
      final personal = TextBook(id: 9, title: 'שבת', isUserBook: true);
      final other = TextBook(id: 6, title: 'עירובין');
      final library = _buildLibrary(bavliBooks: const []);
      library.books.addAll([official, personal, other]);
      for (final b in [official, personal, other]) {
        provider.indexedFilePaths
            .add(IndexingRepository.buildIndexedBookFilePath(b));
      }
      final repository = _ReindexProbeRepository(provider);

      final result = await repository.reindexChangedBooks(
        [official],
        library,
        onProgress: (_, __) {},
      );

      expect(result, isTrue);
      expect(engine.removedTitles, ['שבת']);
      // שני ספרי 'שבת' הוסרו מה-tracking ונשלחו לאינדוקס מחדש; 'עירובין' לא.
      expect(
        provider.indexedFilePaths,
        {IndexingRepository.buildIndexedBookFilePath(other)},
      );
      expect(repository.indexedBooks!.map((b) => b.title).toSet(), {'שבת'});
      expect(repository.indexedBooks, hasLength(2));
    });

    test('רשימה ריקה — לא נוגע במנוע ולא מאנדקס', () async {
      final engine = _RecordingSearchEngine();
      final repository =
          _ReindexProbeRepository(_RecordingTantivyDataProvider(engine));

      final result = await repository.reindexChangedBooks(
        const [],
        _buildLibrary(bavliBooks: const [('שבת', 1)]),
        onProgress: (_, __) {},
      );

      expect(result, isTrue);
      expect(engine.removedTitles, isEmpty);
      expect(repository.indexedBooks, isNull);
    });
  });

  group('IndexingRepository.reconcileIndexWithLibrary', () {
    TextBook book(int id, String title) => TextBook(id: id, title: title);

    test('מזהה ספרים ששונו או בלתי-ניתנים-לאימות ומאנדקס רק אותם מחדש',
        () async {
      final engine = _RecordingSearchEngine();
      final provider = _RecordingTantivyDataProvider(engine);
      final unchanged = book(1, 'שבת');
      final changed = book(2, 'עירובין');
      final notIndexed = book(3, 'פסחים');
      final unverifiable = book(4, 'יומא');
      final unloadable = book(5, 'סוכה');
      final library = _buildLibrary(bavliBooks: const []);
      library.books
          .addAll([unchanged, changed, notIndexed, unverifiable, unloadable]);

      engine.fingerprints = {
        IndexingRepository.buildIndexedBookFilePath(unchanged): BigInt.from(11),
        IndexingRepository.buildIndexedBookFilePath(changed): BigInt.from(21),
        IndexingRepository.buildIndexedBookFilePath(unverifiable): BigInt.zero,
        IndexingRepository.buildIndexedBookFilePath(unloadable):
            BigInt.from(55),
        // notIndexed בכוונה חסר — ספר חדש שמטופל במסלול הרגיל.
      };
      for (final b in [unchanged, changed, unverifiable, unloadable]) {
        provider.indexedFilePaths
            .add(IndexingRepository.buildIndexedBookFilePath(b));
      }

      final texts = {
        'שבת': 'אחד',
        'עירובין': 'שתיים-חדש',
        'יומא': 'שלוש',
        // 'סוכה' חסר — טעינה נכשלת.
      };
      final hashes = {
        'אחד': BigInt.from(11), // תואם לאינדקס — לא השתנה
        'שתיים-חדש': BigInt.from(22), // שונה מ-21 — השתנה
        'שלוש': BigInt.from(33),
      };

      final repository = _ReindexProbeRepository(provider);
      final scanCalls = <(int, int)>[];

      final result = await repository.reconcileIndexWithLibrary(
        library,
        onScanProgress: (p, t) => scanCalls.add((p, t)),
        onProgress: (_, __) {},
        loadText: (b) async => texts[b.title],
        fingerprintOf: (text) async => hashes[text]!,
      );

      expect(result, isTrue);
      expect(
        repository.indexedBooks!.map((b) => b.title).toSet(),
        {'עירובין', 'יומא'},
      );
      expect(engine.removedTitles.toSet(), {'עירובין', 'יומא'});
      // הסריקה כיסתה את חמשת ספרי הטקסט שהוספנו ואת ברירת-המחדל ב"תנ"ך".
      expect(scanCalls.last, (6, 6));
      // isIndexing חוזר ל-false אחרי הסריקה (indexBooks מזויף בטסט).
      expect(provider.isIndexing.value, isFalse);
    });

    test('כשהכל תואם — מסתיים בהצלחה בלי לגעת באינדקס', () async {
      final engine = _RecordingSearchEngine();
      final provider = _RecordingTantivyDataProvider(engine);
      final b = book(1, 'שבת');
      final library = _buildLibrary(bavliBooks: const []);
      library.books.add(b);
      engine.fingerprints = {
        IndexingRepository.buildIndexedBookFilePath(b): BigInt.from(7),
      };

      final repository = _ReindexProbeRepository(provider);
      final result = await repository.reconcileIndexWithLibrary(
        library,
        onProgress: (_, __) {},
        loadText: (_) async => 'טקסט',
        fingerprintOf: (_) async => BigInt.from(7),
      );

      expect(result, isTrue);
      expect(repository.indexedBooks, isNull);
      expect(engine.removedTitles, isEmpty);
    });

    test('ביטול באמצע הסריקה מחזיר false בלי לאנדקס', () async {
      final engine = _RecordingSearchEngine();
      final provider = _RecordingTantivyDataProvider(engine);
      final library = _buildLibrary(bavliBooks: const []);
      library.books.addAll([book(1, 'שבת'), book(2, 'עירובין')]);
      engine.fingerprints = {
        for (final b in library.books)
          IndexingRepository.buildIndexedBookFilePath(b): BigInt.from(9),
      };

      final repository = _ReindexProbeRepository(provider);
      final result = await repository.reconcileIndexWithLibrary(
        library,
        onProgress: (_, __) {},
        loadText: (b) async {
          // מדמה לחיצת ביטול של המשתמש בזמן הסריקה.
          provider.isIndexing.value = false;
          return 'טקסט';
        },
        fingerprintOf: (_) async => BigInt.one,
      );

      expect(result, isFalse);
      expect(repository.indexedBooks, isNull);
    });
  });

  group('IndexingRepository.indexAllBooks', () {
    test('fast path מחזיר מוקדם בלי להפעיל isolate ובלי callbacks', () async {
      final library = _buildLibrary(bavliBooks: const [('שבת', 1)]);
      final indexedFilePaths = library
          .getAllBooks()
          .where(IndexingRepository.isIndexableBook)
          .map(IndexingRepository.buildIndexedBookFilePath)
          .toSet();
      final provider = FakeTantivyDataProvider(
        indexedFilePaths: indexedFilePaths,
        requiresManualReindexValue: false,
      );
      final isolateService = FakeIndexingIsolateService();

      final repository = IndexingRepository(
        provider,
        isolateService: isolateService,
      );

      var actualIndexingStarted = false;
      var progressCalls = 0;

      final result = await repository.indexAllBooks(
        library,
        onActualIndexingStarted: () {
          actualIndexingStarted = true;
        },
        onProgress: (_, __) {
          progressCalls++;
        },
      );

      expect(result, isTrue);
      expect(actualIndexingStarted, isFalse);
      expect(progressCalls, 0);
      expect(isolateService.wasUsed, isFalse);
    });

    test('לא מדלג ב-fast path כשנדרש manual reindex', () async {
      final library = _buildLibrary(bavliBooks: const [('שבת', 1)]);
      final indexedFilePaths = library
          .getAllBooks()
          .where(IndexingRepository.isIndexableBook)
          .map(IndexingRepository.buildIndexedBookFilePath)
          .toSet();
      final provider = FakeTantivyDataProvider(
        indexedFilePaths: indexedFilePaths,
        requiresManualReindexValue: true,
      );
      final isolateService = FakeIndexingIsolateService();

      final repository = IndexingRepository(
        provider,
        isolateService: isolateService,
      );

      var actualIndexingStarted = false;
      var progressCalls = 0;

      final result = await repository.indexAllBooks(
        library,
        onActualIndexingStarted: () {
          actualIndexingStarted = true;
        },
        onProgress: (_, __) {
          progressCalls++;
        },
      );

      expect(result, isFalse);
      expect(actualIndexingStarted, isFalse);
      expect(progressCalls, 0);
      expect(isolateService.wasUsed, isFalse);
    });
  });

  group('IndexingRepository.buildCatalogueDocumentId', () {
    test('נותן עדיפות לסדר הספר לפני הסדר הפנימי בתוך הספר', () {
      final earlierBookLateSegment =
          IndexingRepository.buildCatalogueDocumentId(
        catalogueOrder: 0,
        ordinal: 500,
      );
      final laterBookFirstSegment = IndexingRepository.buildCatalogueDocumentId(
        catalogueOrder: 1,
        ordinal: 0,
      );

      expect(earlierBookLateSegment, lessThan(laterBookFirstSegment));
    });
  });

  group('IndexingRepository.catalogueOrderKey', () {
    test('מבדיל בין קבצי PDF עם אותו שם לפי הנתיב בפועל', () {
      final first = PdfBook(
        title: 'שבת',
        path: r'C:\books\a.pdf',
        categoryPath: 'תלמוד בבלי, סדר מועד',
      );
      final second = PdfBook(
        title: 'שבת',
        path: r'C:\books\b.pdf',
        categoryPath: 'תלמוד בבלי, סדר מועד',
      );

      expect(
        IndexingRepository.catalogueOrderKey(first),
        isNot(IndexingRepository.catalogueOrderKey(second)),
      );
    });

    test('מבדיל בין ספר רשמי לספר אישי עם אותו id (חפיפת AUTOINCREMENT)', () {
      // id טבעי זהה בשני ה-DB — בלי תיוג המקור הספר האישי מדולג באינדוקס.
      final official = TextBook(id: 5, title: 'שבת');
      final userBook = TextBook(id: 5, title: 'הערות אישיות', isUserBook: true);

      expect(IndexingRepository.catalogueOrderKey(official), 'id:5');
      expect(IndexingRepository.catalogueOrderKey(userBook), 'uid:5');
    });
  });

  group('IndexingRepository.buildIndexedBookFilePath', () {
    test('PdfBook ממופה לנתיב הקובץ, ספר טקסט למפתח הקטלוג', () {
      // המפתח הזה הוא שדה filePath של המסמכים באינדקס, ולכן הוא הבסיס
      // לשחזור מצב האינדוקס מהאינדקס עצמו (getIndexedFilePaths).
      final pdf = PdfBook(
        title: 'שבת',
        path: r'C:\books\a.pdf',
        categoryPath: 'תלמוד בבלי, סדר מועד',
      );
      final text = TextBook(title: 'בראשית');

      expect(IndexingRepository.buildIndexedBookFilePath(pdf), pdf.path);
      expect(
        IndexingRepository.buildIndexedBookFilePath(text),
        IndexingRepository.catalogueOrderKey(text),
      );
    });
  });

  group('IndexingRepository.isIndexableBook', () {
    test('DocxBook נכלל באינדוקס דרך מיפוי ל-TextBook', () {
      // רגרסיה: לפני התיקון `isIndexableBook` החזיר false ל-DocxBook,
      // אז `IndexingBloc` סינן אותו לפני indexAllBooks וקבצי DOCX לא נכנסו
      // לאינדקס הטנטיווי. עכשיו הוא ממופה ל-TextBook באמצעות `toTextBook()`
      // ו-`book.text` מחלץ את התוכן דרך docxToText ב-DatabaseLibraryProvider.
      final docx = DocxBook(
        id: 1,
        title: 'בדיקה',
        path: r'C:\library\בדיקה.docx',
        categoryId: 10,
      );
      expect(IndexingRepository.isIndexableBook(docx), isTrue);
    });

    test('TextBook ו-PdfBook נשארים אינדוקסיביליים', () {
      expect(
        IndexingRepository.isIndexableBook(TextBook(title: 'א')),
        isTrue,
      );
      expect(
        IndexingRepository.isIndexableBook(
          PdfBook(title: 'א', path: r'C:\a.pdf'),
        ),
        isTrue,
      );
    });

    test('ExternalLibraryBook לא אינדוקסיבילי', () {
      final external = ExternalLibraryBook(
        title: 'אוצר',
        id: 999,
        link: 'https://example.com',
      );
      expect(IndexingRepository.isIndexableBook(external), isFalse);
    });
  });

  group('DocxBook ↔ TextBook(wrap) — עקביות מפתח קטלוג', () {
    test('catalogueOrderKey זהה ל-DocxBook ול-TextBook העטוף עם id', () {
      // קריטי: שני המפתחות חייבים להיות זהים כדי שבדיקת isBookIndexed
      // (לפי filePath שנקרא מהאינדקס) תזהה אותו ספר בלי לכפול
      // את האינדוקס בהפעלות חוזרות.
      final docx = DocxBook(
        id: 42,
        title: 'בדיקה',
        path: r'C:\library\בדיקה.docx',
        categoryId: 7,
      );
      expect(
        IndexingRepository.catalogueOrderKey(docx),
        IndexingRepository.catalogueOrderKey(docx.toTextBook()),
      );
    });

    test('catalogueOrderKey זהה גם ללא id (נופל ל-title|category|docx|path)',
        () {
      // FileBook משתמש ב-`book.path` ב-pathKey, ו-TextBook (לא FileBook)
      // משתמש ב-`book.filePath`. `toTextBook()` מעביר `filePath ?? path`,
      // כך שהמפתח נשאר עקבי גם בלי id.
      final docx = DocxBook(
        title: 'בדיקה ללא id',
        path: r'C:\library\בדיקה.docx',
        categoryPath: 'ספרים אישיים',
      );
      expect(
        IndexingRepository.catalogueOrderKey(docx),
        IndexingRepository.catalogueOrderKey(docx.toTextBook()),
      );
    });
  });

  group('IndexingRepository.optimizeIndexBestEffort', () {
    test('מחזיר true כש-optimize מצליח', () async {
      var called = false;

      final completed =
          await IndexingRepository.optimizeIndexBestEffort(() async {
        called = true;
      });

      expect(called, isTrue);
      expect(completed, isTrue);
    });

    test('מחזיר false ולא זורק כש-optimize נכשל אחרי commit', () async {
      Object? reportedError;

      final completed =
          await IndexingRepository.optimizeIndexBestEffort(() async {
        throw StateError('maintenance failed');
      }, onFailure: (error, _) {
        reportedError = error;
      });

      expect(completed, isFalse);
      expect(reportedError, isA<StateError>());
    });
  });
}

class FakeTantivyDataProvider implements TantivyDataProvider {
  FakeTantivyDataProvider({
    required this.indexedFilePaths,
    required bool requiresManualReindexValue,
  }) : _requiresManualReindexValue = requiresManualReindexValue;

  final bool _requiresManualReindexValue;

  @override
  final Set<String> indexedFilePaths;

  @override
  bool get requiresManualReindex => _requiresManualReindexValue;

  @override
  Future<SearchEngine> get engine async => _FakeSearchEngine();

  @override
  set engine(Future<SearchEngine> value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Unexpected call: $invocation');
  }
}

class _FakeSearchEngine implements SearchEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Unexpected call: $invocation');
  }
}

/// ספק עם מנוע יציב המקליט קריאות — לבדיקת ניקוי רשומות אינדקס שהועברו.
class _RecordingTantivyDataProvider implements TantivyDataProvider {
  _RecordingTantivyDataProvider(this._engine);

  final _RecordingSearchEngine _engine;

  @override
  final Set<String> indexedFilePaths = {};

  @override
  final ValueNotifier<bool> isIndexing = ValueNotifier<bool>(false);

  @override
  bool get requiresManualReindex => false;

  @override
  Future<SearchEngine> get engine async => _engine;

  @override
  set engine(Future<SearchEngine> value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Unexpected call: $invocation');
  }
}

/// עוקף את indexBooks כדי לבדוק את reindexChangedBooks בבידוד: הרחבת
/// הכותרות והמחיקה אמיתיות, האינדוקס עצמו רק מוקלט.
class _ReindexProbeRepository extends IndexingRepository {
  _ReindexProbeRepository(super.provider);

  List<Book>? indexedBooks;

  @override
  Future<bool> indexBooks(
    List<Book> books,
    Library library, {
    void Function()? onActualIndexingStarted,
    required void Function(int processed, int total) onProgress,
  }) async {
    indexedBooks = books;
    return true;
  }
}

class _RecordingSearchEngine implements SearchEngine {
  final List<String> removedTitles = [];
  int commitCount = 0;

  /// טביעות-אצבע פר-ספר שהמנוע "קרא מהאינדקס" — לבדיקות reconcile.
  Map<String, BigInt> fingerprints = {};

  @override
  Future<void> removeDocumentsByTitle({required String title}) async {
    removedTitles.add(title);
  }

  @override
  Future<void> commit() async {
    commitCount++;
  }

  @override
  Future<Map<String, BigInt>> getBookFingerprints() async => fingerprints;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Unexpected call: $invocation');
  }
}

class FakeIndexingIsolateService implements IndexingIsolateService {
  bool wasUsed = false;

  @override
  Future<void> cancelActiveWork() async {
    wasUsed = true;
  }

  @override
  Future<void> dispose() async {
    wasUsed = true;
  }

  @override
  Future<Stream<IndexingIsolateUpdate>> processPdfPages({
    required List<({String reference, String text, int pageIndex})> pages,
  }) async {
    wasUsed = true;
    return const Stream.empty();
  }

  @override
  Future<Stream<IndexingIsolateUpdate>> processTextBook({
    required String text,
  }) async {
    wasUsed = true;
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('Unexpected call: $invocation');
  }
}

Library _buildLibrary({
  required List<(String, int)> bavliBooks,
  List<Book> additionalBooks = const [],
}) {
  final library = Library(categories: []);
  final tanakh = Category(
    title: 'תנ"ך',
    description: '',
    shortDescription: '',
    order: 1,
    subCategories: [],
    books: [],
    parent: library,
  );
  final bavli = Category(
    title: 'תלמוד בבלי',
    description: '',
    shortDescription: '',
    order: 2,
    subCategories: [],
    books: [],
    parent: library,
  );
  library.subCategories.addAll([tanakh, bavli]);

  tanakh.books.add(
    TextBook(title: 'בראשית', order: 1, category: tanakh),
  );

  bavli.books.addAll(
    bavliBooks
        .map(
          (entry) => TextBook(
            title: entry.$1,
            order: entry.$2,
            category: bavli,
          ),
        )
        .toList(),
  );

  library.books.addAll(additionalBooks);

  return library;
}
