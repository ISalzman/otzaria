import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

/// In-memory cache for the `book_acronym` table, used for matching
/// book acronyms and alternative titles (FindRef, library book search).
///
/// המונחים נשמרים במצב מנורמל מראש (ללא ניקוד/גרשיים) כדי לחסוך
/// נורמליזציה חוזרת בכל חיפוש.
class AcronymsCache {
  AcronymsCache._();

  static final AcronymsCache instance = AcronymsCache._();

  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  /// מונה דורות לזיהוי [clear] שקרה במהלך טעינה.
  int _generation = 0;

  final Map<int, List<String>> _acronymsByBookId = <int, List<String>>{};

  bool get isLoaded => _isLoaded;

  /// Returns all normalized acronyms for a given book ID.
  /// כל ערך כבר עבר [normalizeForFindRefMatch] בעת הטעינה.
  List<String>? getAcronymsForBook(int bookId) => _acronymsByBookId[bookId];

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
    final repository = SqliteDataProvider.instance.repository;
    if (repository == null) {
      debugPrint('[AcronymsCache] DB not initialized; skipping warmup');
      if (myGen == _generation) {
        _acronymsByBookId.clear();
        _isLoaded = false;
      }
      return;
    }

    try {
      final db = await repository.database.database;
      if (myGen != _generation) return; // הופסק על ידי clear()

      final acrRows = db.select(
        'SELECT bookId, term FROM book_acronym ORDER BY bookId',
      );

      // בונים למפה מקומית — ה-cache החי לא נוגע עד ה-swap בסוף.
      // נורמליזציה של regex היא היקרה כאן (כל ראש-תיבות) — יציאה ל-event
      // loop כל chunk כדי לא לחסום את ה-UI thread.
      final local = <int, List<String>>{};
      const yieldBatch = 1000;
      var i = 0;
      for (final row in acrRows) {
        final bookId = row['bookId'] as int;
        final term = (row['term'] as String?) ?? '';
        if (term.isEmpty) continue;
        final normalized = normalizeForFindRefMatch(term);
        if (normalized.isEmpty) continue;
        local.putIfAbsent(bookId, () => <String>[]).add(normalized);
        if (++i % yieldBatch == 0) {
          await Future<void>.delayed(Duration.zero);
          if (myGen != _generation) return; // הופסק על ידי clear()
        }
      }

      if (myGen != _generation) return;
      _acronymsByBookId
        ..clear()
        ..addAll(local);
      _isLoaded = true;
      debugPrint(
        '[AcronymsCache] Loaded ${acrRows.length} acronyms for ${_acronymsByBookId.length} books',
      );
    } catch (e) {
      debugPrint('[AcronymsCache] Warmup failed: $e');
      // לא מסמנים loaded: כשל זמני (למשל DB locked בעלייה) יאופשר retry
      // ב-warmUp הבא, במקום ראשי-תיבות ריקים לכל ה-session.
      if (myGen == _generation) {
        _acronymsByBookId.clear();
      }
    }
  }

  void clear() {
    _generation++;
    _acronymsByBookId.clear();
    _isLoaded = false;
    _loadingFuture = null;
  }
}
