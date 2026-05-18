import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:otzaria/data/cache/books_cache.dart';
import 'package:otzaria/data/cache/acronyms_cache.dart';
import 'package:otzaria/data/data_providers/book_composite_key.dart';
import 'package:otzaria/data/data_providers/book_database_resolver.dart';
import 'package:otzaria/data/data_providers/file_system_library_provider.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';
import 'package:pdfrx/pdfrx.dart';

/// In-memory cache for reference finding.
///
/// Uses shared caches:
/// - BooksCache: shared with library screen (book table)
/// - AcronymsCache: exclusive to FindRef (book_acronym table)
///
/// This avoids loading the same data twice into memory.
/// Scope: only the "book selection" phase. TOC lookup is handled elsewhere.
class ReferenceBooksCache {
  ReferenceBooksCache._();

  static final ReferenceBooksCache instance = ReferenceBooksCache._();

  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  /// מונה דורות לזיהוי [clear] שקרה במהלך טעינה.
  int _generation = 0;

  // Normalized titles cache (computed from BooksCache)
  final Map<int, String> _normalizedTitles = <int, String>{};

  // PDF books from file system (not in DB) — stored as (normalizedTitle, hit)
  final List<(String, ReferenceBookHit)> _fsPdfBooks =
      <(String, ReferenceBookHit)>[];

  // Lazy PDF outline cache: filePath → Future of outline entries
  // Populated on demand (and optionally pre-warmed in background after warmUp).
  final Map<String, Future<List<(String, String, int)>>> _pdfOutlineCache =
      <String, Future<List<(String, String, int)>>>{};

  /// פונקציית הפענוח של outline מ-PDF. ניתן להחליפה בבדיקות כדי להחליף את
  /// ה-I/O הממשי בפעולה דטרמיניסטית, בלי להוציא את התלות ב-pdfrx לחוץ.
  @visibleForTesting
  Future<List<(String, String, int)>> Function(String filePath)
      pdfOutlineParser = _parsePdfOutlineEntries;

  bool get isLoaded => _isLoaded;

  Future<void> warmUp() async {
    if (_isLoaded) return;
    if (_loadingFuture != null) return _loadingFuture;

    _loadingFuture = _loadInternal();

    try {
      await _loadingFuture;
    } finally {
      _loadingFuture = null;
    }
  }

  Future<void> _loadInternal() async {
    final myGen = _generation;
    try {
      // Warm up shared caches
      await BooksCache.instance.warmUp();
      if (myGen != _generation) return;
      await AcronymsCache.instance.warmUp();
      if (myGen != _generation) return;

      // Pre-compute normalized titles for fast matching.
      // בונים למפה מקומית — ה-cache החי לא נוגע עד ה-swap בסוף.
      // יציאה ל-event loop כל chunk כדי לא לחסום את ה-UI thread על
      // ספריות גדולות (~50K ספרים × regex לנורמליזציה).
      final localNormalizedTitles = <int, String>{};
      const yieldBatch = 1000;
      var processed = 0;
      for (final book in BooksCache.instance.books) {
        localNormalizedTitles[book.id] = _normalizeForMatch(book.title);
        if (++processed % yieldBatch == 0) {
          await Future<void>.delayed(Duration.zero);
          if (myGen != _generation) return;
        }
      }

      // Collect DB PDF titles to avoid duplicates with file-system PDFs
      final dbPdfTitles = BooksCache.instance.books
          .where((b) => b.fileType == 'pdf')
          .map((b) => b.title)
          .toSet();

      // מפה מכותרת → orderIndex הנמוך ביותר מקרב כל ספרי ה-DB (כולל טקסט).
      // FS PDF בעל אותה כותרת כספר DB יירש את ה-orderIndex שלו, כדי שלא
      // ידחק לסוף הרשימה (999.0 קבוע).
      final titleToDbOrderIndex = <String, double>{};
      for (final book in BooksCache.instance.books) {
        final existing = titleToDbOrderIndex[book.title];
        if (existing == null || book.orderIndex < existing) {
          titleToDbOrderIndex[book.title] = book.orderIndex;
        }
      }

      // Load PDF books from file system that are not in the DB.
      // PDF outline parsing is NOT done here — it happens lazily via getPdfOutlineEntries().
      final localFsPdfBooks = <(String, ReferenceBookHit)>[];
      if (FileSystemLibraryProvider.instance.isInitialized) {
        final keyToPath = await FileSystemLibraryProvider.instance.keyToPath;
        if (myGen != _generation) return;
        var processedPdfs = 0;
        for (final entry in keyToPath.entries) {
          final key = BookCompositeKey.tryParse(entry.key);
          if (key == null || key.fileType != 'pdf') continue;
          if (dbPdfTitles.contains(key.title)) continue;

          final normalizedTitle = _normalizeForMatch(key.title);
          if (normalizedTitle.isEmpty) continue;

          // FS PDF inherits the DB book's orderIndex when one exists with the same title,
          // preventing it from being pushed behind all text books (default 999.0).
          final orderIdx = titleToDbOrderIndex[key.title] ?? 999.0;

          localFsPdfBooks.add((
            normalizedTitle,
            ReferenceBookHit(
              bookId: -1,
              title: key.title,
              normalizedTitle: normalizedTitle,
              filePath: entry.value,
              fileType: 'pdf',
              matchRank: 0,
              orderIndex: orderIdx,
            ),
          ));
          if (++processedPdfs % yieldBatch == 0) {
            await Future<void>.delayed(Duration.zero);
            if (myGen != _generation) return;
          }
        }
      }

      // Swap אטומי — רק אם הדור עדיין שלנו.
      if (myGen != _generation) return;
      _normalizedTitles
        ..clear()
        ..addAll(localNormalizedTitles);
      _fsPdfBooks
        ..clear()
        ..addAll(localFsPdfBooks);
      _isLoaded = true;
      debugPrint(
        '[ReferenceBooksCache] Ready with ${BooksCache.instance.books.length} DB books'
        ' + ${_fsPdfBooks.length} FS PDF books',
      );

      // Pre-warm PDF outlines in the background — typically 20-40 FS PDFs,
      // each requiring a file open + outline parse on first FindRef hit.
      // Running here (post-swap) keeps `warmUp()`'s returned Future fast,
      // while the throttled parse fills the cache before the user types.
      unawaited(prewarmAllPdfOutlines().catchError((Object e) {
        debugPrint('[ReferenceBooksCache] PDF outline pre-warm failed: $e');
      }));
    } catch (e) {
      debugPrint('[ReferenceBooksCache] Warmup failed: $e');
      if (myGen == _generation) {
        _normalizedTitles.clear();
        _fsPdfBooks.clear();
        _isLoaded = true;
      }
    }
  }

  void clear() {
    _generation++;
    _normalizedTitles.clear();
    _fsPdfBooks.clear();
    _pdfOutlineCache.clear();
    _categoryPaths.clear();
    _isLoaded = false;
    _loadingFuture = null;
    // Note: We don't clear the shared caches here as they may be used by other components
  }

  // Lazy category-path cache: bookId → category path string (e.g., "תנ"ך, תורה, בראשית")
  final Map<int, String> _categoryPaths = <int, String>{};

  /// מחזיר את נתיב הקטגוריה עבור ספר לפי מזההו.
  /// הנתיב נבנה בפעם הראשונה בלבד ונשמר בזיכרון.
  Future<String> getCategoryPathForBook(int bookId) async {
    if (bookId < 0) return '';
    if (_categoryPaths.containsKey(bookId)) return _categoryPaths[bookId]!;

    final book = BooksCache.instance.getBookById(bookId);
    if (book == null) {
      _categoryPaths[bookId] = '';
      return '';
    }

    final repository = SqliteDataProvider.instance.repository;
    if (repository == null) {
      _categoryPaths[bookId] = '';
      return '';
    }

    try {
      final path = await BookDatabaseResolver.buildCategoryPath(
          repository, book.categoryId);
      _categoryPaths[bookId] = path;
      return path;
    } catch (e) {
      debugPrint('[ReferenceBooksCache] getCategoryPathForBook error: $e');
      _categoryPaths[bookId] = '';
      return '';
    }
  }

  /// Returns outline entries for a file-system PDF, parsed lazily and cached.
  /// Each entry is (normalizedTitle, originalTitle, pageNumber).
  Future<List<(String, String, int)>> getPdfOutlineEntries(
      String filePath) async {
    return _pdfOutlineCache.putIfAbsent(
        filePath, () => pdfOutlineParser(filePath));
  }

  /// Pre-warms the PDF outline cache for all currently-known FS PDF books.
  ///
  /// Runs in bounded batches of [maxConcurrent] files at a time to avoid
  /// opening dozens of PdfDocument objects simultaneously (pdfrx serializes
  /// work in a single background isolate, but each open file holds memory).
  ///
  /// Idempotent and cheap to re-run: entries already cached are skipped
  /// automatically by [getPdfOutlineEntries]'s `putIfAbsent`.
  ///
  /// Respects [clear] via the generation counter — if the cache is cleared
  /// mid-run, the remaining batches are aborted.
  Future<void> prewarmAllPdfOutlines({int maxConcurrent = 4}) async {
    // ולידציה רצה גם ב-release: ערך לא חיובי יוצר לולאה אינסופית
    // (i += 0), עדיף להיכשל בקול מאשר להקפיא את ה-isolate.
    if (maxConcurrent <= 0) {
      throw ArgumentError.value(
          maxConcurrent, 'maxConcurrent', 'must be > 0');
    }
    final gen = _generation;
    final paths = _fsPdfBooks
        .map((entry) => entry.$2.filePath)
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) return;

    for (var i = 0; i < paths.length; i += maxConcurrent) {
      if (gen != _generation) return;
      final end =
          (i + maxConcurrent < paths.length) ? i + maxConcurrent : paths.length;
      await Future.wait([
        for (var j = i; j < end; j++) getPdfOutlineEntries(paths[j]),
      ]);
    }
    debugPrint(
      '[ReferenceBooksCache] PDF outline pre-warm complete '
      '(${paths.length} files)',
    );
  }

  /// בדיקות בלבד — מאפשר למלא את רשימת ה-FS PDFs בלי לעבור דרך
  /// [FileSystemLibraryProvider].
  @visibleForTesting
  void setFsPdfBooksForTesting(List<(String, ReferenceBookHit)> books) {
    _fsPdfBooks
      ..clear()
      ..addAll(books);
  }

  /// בדיקות בלבד — חושף את מצב מטמון ה-outline (filePath → Future של ערכי
  /// outline) כדי לבדוק אילו קבצים נטענו.
  @visibleForTesting
  Map<String, Future<List<(String, String, int)>>>
      get pdfOutlineCacheForTesting => _pdfOutlineCache;

  /// Searches books by title and acronym from memory.
  ///
  /// Input must already be normalized similarly to [_normalizeForMatch], but we
  /// normalize again defensively.
  List<ReferenceBookHit> search(String query, {int limit = 50}) {
    final q = _normalizeForMatch(query);
    if (q.isEmpty) return const <ReferenceBookHit>[];

    final starts = <ReferenceBookHit>[];
    final contains = <ReferenceBookHit>[];

    for (final book in BooksCache.instance.books) {
      final t = _normalizedTitles[book.id] ?? '';
      if (t.isEmpty) continue;

      int? matchRank;
      String? matchedTerm;

      if (t == q) {
        matchRank = 0;
      } else if (t.startsWith(q)) {
        matchRank = 1;
      } else if (t.contains(q)) {
        matchRank = 2;
      } else {
        // התאמת ראשי תיבות — המונחים כבר מנורמלים בעת טעינת הקאש.
        final normalizedAcronyms =
            AcronymsCache.instance.getAcronymsForBook(book.id);
        if (normalizedAcronyms != null) {
          for (final a in normalizedAcronyms) {
            if (a == q) {
              matchRank = 3;
              matchedTerm = a;
              break;
            }
            if (a.startsWith(q)) {
              matchRank ??= 4;
              matchedTerm ??= a;
            } else if (a.contains(q)) {
              matchRank ??= 5;
              matchedTerm ??= a;
            }
          }
        }
      }

      if (matchRank == null) continue;

      final hit = ReferenceBookHit(
        bookId: book.id,
        title: book.title,
        normalizedTitle: t,
        filePath: book.filePath ?? '',
        fileType: book.fileType,
        matchRank: matchRank,
        matchedTerm: matchedTerm,
        orderIndex: book.orderIndex,
      );

      if (matchRank <= 1) {
        starts.add(hit);
      } else {
        contains.add(hit);
      }
    }

    // Search file-system PDF books
    for (final (t, baseHit) in _fsPdfBooks) {
      int? matchRank;
      if (t == q) {
        matchRank = 0;
      } else if (t.startsWith(q)) {
        matchRank = 1;
      } else if (t.contains(q)) {
        matchRank = 2;
      }
      if (matchRank == null) continue;

      final hit = ReferenceBookHit(
        bookId: baseHit.bookId,
        title: baseHit.title,
        normalizedTitle: t,
        filePath: baseHit.filePath,
        fileType: baseHit.fileType,
        matchRank: matchRank,
        orderIndex: baseHit.orderIndex,
      );

      if (matchRank <= 1) {
        starts.add(hit);
      } else {
        contains.add(hit);
      }
    }

    int cmp(ReferenceBookHit a, ReferenceBookHit b) {
      final r = a.matchRank.compareTo(b.matchRank);
      if (r != 0) return r;
      // Prefer lower orderIndex, then shorter title.
      final o = a.orderIndex.compareTo(b.orderIndex);
      if (o != 0) return o;
      return a.title.length.compareTo(b.title.length);
    }

    starts.sort(cmp);
    contains.sort(cmp);

    final merged = <ReferenceBookHit>[...starts, ...contains];
    return merged.length > limit ? merged.take(limit).toList() : merged;
  }

  static String _normalizeForMatch(String input) =>
      normalizeForFindRefMatch(input);

  static Future<List<(String, String, int)>> _parsePdfOutlineEntries(
      String filePath) async {
    try {
      final doc = await PdfDocument.openFile(filePath);
      final outline = await doc.loadOutline();
      final entries = <(String, String, int)>[];
      _collectOutlineEntries(outline, entries, maxDepth: 2, currentDepth: 0);
      debugPrint(
          '[ReferenceBooksCache] Parsed ${entries.length} outline entries for $filePath');
      return entries;
    } catch (e) {
      debugPrint(
          '[ReferenceBooksCache] Failed to parse outline for $filePath: $e');
      return const [];
    }
  }

  static void _collectOutlineEntries(
    List<PdfOutlineNode> nodes,
    List<(String, String, int)> out, {
    required int maxDepth,
    required int currentDepth,
  }) {
    if (currentDepth >= maxDepth) return;
    for (final node in nodes) {
      final page = node.dest?.pageNumber;
      if (page != null && node.title.isNotEmpty) {
        out.add((_normalizeForMatch(node.title), node.title, page));
      }
      _collectOutlineEntries(node.children, out,
          maxDepth: maxDepth, currentDepth: currentDepth + 1);
    }
  }
}

class ReferenceBookHit {
  final int bookId;
  final String title;

  /// הכותרת לאחר [normalizeForFindRefMatch], מחושבת מראש במטמון
  /// כדי לחסוך נורמליזציה חוזרת בצרכן.
  final String normalizedTitle;
  final String filePath;
  final String fileType;
  final int matchRank;
  final String? matchedTerm;
  final double orderIndex;

  const ReferenceBookHit({
    required this.bookId,
    required this.title,
    required this.normalizedTitle,
    required this.filePath,
    required this.fileType,
    required this.matchRank,
    required this.orderIndex,
    this.matchedTerm,
  });
}
