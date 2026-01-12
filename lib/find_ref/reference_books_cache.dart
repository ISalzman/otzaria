import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/utils/text_manipulation.dart';

/// In-memory cache for reference finding.
///
/// Loads (once per app run) the data needed to quickly match a book by its
/// title or acronym, without hitting SQLite on every keystroke.
///
/// Scope: only the "book selection" phase. TOC lookup is handled elsewhere.
class ReferenceBooksCache {
  ReferenceBooksCache._();

  static final ReferenceBooksCache instance = ReferenceBooksCache._();

  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  final List<_BookRow> _books = <_BookRow>[];
  final Map<int, List<String>> _acronymsByBookId = <int, List<String>>{};

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
    final repository = SqliteDataProvider.instance.repository;
    if (repository == null) {
      debugPrint('[ReferenceBooksCache] DB not initialized; skipping warmup');
      _books.clear();
      _acronymsByBookId.clear();
      // Keep as not-loaded so we can warm up later after DB is created/initialized.
      _isLoaded = false;
      return;
    }

    try {
      final allBooks = await repository.database.bookDao.getAllBooks();

      _books
        ..clear()
        ..addAll(
          allBooks.map(
            (b) => _BookRow(
              id: b.id,
              title: b.title,
              titleNorm: _normalizeForMatch(b.title),
              filePath: b.filePath,
              fileType: b.fileType ?? 'txt',
              orderIndex: b.order,
            ),
          ),
        );

      final db = await repository.database.database;
      final acrRows = await db.rawQuery(
        'SELECT bookId, term FROM book_acronym ORDER BY bookId',
      );

      _acronymsByBookId.clear();
      for (final row in acrRows) {
        final bookId = row['bookId'] as int;
        final term = (row['term'] as String?) ?? '';
        final norm = _normalizeForMatch(term);
        if (norm.isEmpty) continue;
        _acronymsByBookId.putIfAbsent(bookId, () => <String>[]).add(norm);
      }

      _isLoaded = true;
      debugPrint(
        '[ReferenceBooksCache] Loaded ${_books.length} books, '
        '${acrRows.length} acronyms',
      );
    } catch (e) {
      debugPrint('[ReferenceBooksCache] Warmup failed: $e');
      _books.clear();
      _acronymsByBookId.clear();
      // Mark loaded to avoid repeated attempts per keystroke; caller can decide
      // to clear() and warmUp() again.
      _isLoaded = true;
    }
  }

  void clear() {
    _books.clear();
    _acronymsByBookId.clear();
    _isLoaded = false;
    _loadingFuture = null;
  }

  /// Searches books by title and acronym from memory.
  ///
  /// Input must already be normalized similarly to [_normalizeForMatch], but we
  /// normalize again defensively.
  List<ReferenceBookHit> search(String query, {int limit = 50}) {
    final q = _normalizeForMatch(query);
    if (q.isEmpty) return const <ReferenceBookHit>[];

    final starts = <ReferenceBookHit>[];
    final contains = <ReferenceBookHit>[];

    for (final b in _books) {
      final t = b.titleNorm;
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
        // acronym match
        final acrs = _acronymsByBookId[b.id];
        if (acrs != null) {
          for (final a in acrs) {
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
        bookId: b.id,
        title: b.title,
        filePath: b.filePath ?? '',
        fileType: b.fileType,
        matchRank: matchRank,
        matchedTerm: matchedTerm,
        orderIndex: b.orderIndex,
      );

      // Keep two buckets for cheap ordering.
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

  static String _normalizeForMatch(String input) {
    var cleaned = removeTeamim(removeVolwels(input));
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\u0590-\u05FF\s]'), ' ');
    cleaned = cleaned.toLowerCase();
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class ReferenceBookHit {
  final int bookId;
  final String title;
  final String filePath;
  final String fileType;
  final int matchRank;
  final String? matchedTerm;
  final double orderIndex;

  const ReferenceBookHit({
    required this.bookId,
    required this.title,
    required this.filePath,
    required this.fileType,
    required this.matchRank,
    required this.orderIndex,
    this.matchedTerm,
  });
}

class _BookRow {
  final int id;
  final String title;
  final String titleNorm;
  final String? filePath;
  final String fileType;
  final double orderIndex;

  const _BookRow({
    required this.id,
    required this.title,
    required this.titleNorm,
    required this.filePath,
    required this.fileType,
    required this.orderIndex,
  });
}
