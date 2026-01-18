import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';

/// Shared in-memory cache for the `book` table.
///
/// This cache is used by both:
/// - Library screen (DatabaseLibraryProvider) for displaying books
/// - FindRef feature for matching book titles
///
/// By sharing this cache, we avoid loading the same data twice into memory.
class BooksCache {
  BooksCache._();

  static final BooksCache instance = BooksCache._();

  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  final List<BookCacheEntry> _books = <BookCacheEntry>[];
  final Map<int, BookCacheEntry> _booksById = <int, BookCacheEntry>{};

  bool get isLoaded => _isLoaded;

  /// Returns all cached books
  List<BookCacheEntry> get books => List.unmodifiable(_books);

  /// Returns a book by its ID, or null if not found
  BookCacheEntry? getBookById(int id) => _booksById[id];

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
    final repository = SqliteDataProvider.instance.repository;
    if (repository == null) {
      debugPrint('[BooksCache] DB not initialized; skipping warmup');
      _books.clear();
      _booksById.clear();
      _isLoaded = false;
      return;
    }

    try {
      final allBooks = await repository.database.bookDao.getAllBooks();

      _books.clear();
      _booksById.clear();

      for (final b in allBooks) {
        final entry = BookCacheEntry(
          id: b.id,
          title: b.title,
          filePath: b.filePath,
          fileType: b.fileType ?? 'txt',
          categoryId: b.categoryId,
          orderIndex: b.order,
        );
        _books.add(entry);
        _booksById[b.id] = entry;
      }

      _isLoaded = true;
      debugPrint(
          '[BooksCache] Loaded ${_books.length} books into shared cache');
    } catch (e) {
      debugPrint('[BooksCache] Warmup failed: $e');
      _books.clear();
      _booksById.clear();
      _isLoaded = true; // Mark as loaded to avoid repeated attempts
    }
  }

  void clear() {
    _books.clear();
    _booksById.clear();
    _isLoaded = false;
    _loadingFuture = null;
  }
}

/// Represents a single book entry in the cache
class BookCacheEntry {
  final int id;
  final String title;
  final String? filePath;
  final String fileType;
  final int categoryId;
  final double orderIndex;

  const BookCacheEntry({
    required this.id,
    required this.title,
    required this.filePath,
    required this.fileType,
    required this.categoryId,
    required this.orderIndex,
  });
}
