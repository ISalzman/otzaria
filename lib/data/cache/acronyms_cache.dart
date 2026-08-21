import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:otzaria/data/data_providers/sqlite_data_provider.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

/// קבוצת-על ממוינת של מזהי ספרים שכינוי שלהם עלול להתאים לשאילתה.
/// הבדיקה היא חיפוש בינארי — ללא הקצאות, כדי שתרוץ פעם אחת לכל ספר בכל הקלדה.
class AcronymCandidateBooks {
  const AcronymCandidateBooks._(this._sortedBookIds);

  final Int32List _sortedBookIds;

  /// האם ייתכן שכינוי של [bookId] מתאים לשאילתה. ההכרעה נשארת בידי הקורא —
  /// זו קבוצת-על.
  bool contains(int bookId) {
    var low = 0;
    var high = _sortedBookIds.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final value = _sortedBookIds[mid];
      if (value == bookId) return true;
      if (value < bookId) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return false;
  }

  /// בדיקות בלבד — מספר הספרים שנותרו לסריקה.
  @visibleForTesting
  int get length => _sortedBookIds.length;
}

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

  /// אינדקס ביגרמים: לכל צמד תווים סמוכים שמופיע במונח כלשהו — מזהי הספרים
  /// שלהם יש מונח כזה, ממוינים. המפתח הוא `(תו ראשון << 16) | תו שני`.
  final Map<int, Int32List> _bookIdsByBigram = <int, Int32List>{};

  static final AcronymCandidateBooks _noCandidates = AcronymCandidateBooks._(
    Int32List(0),
  );

  bool get isLoaded => _isLoaded;

  /// Returns all normalized acronyms for a given book ID.
  /// כל ערך כבר עבר [normalizeForFindRefMatch] בעת הטעינה.
  List<String>? getAcronymsForBook(int bookId) => _acronymsByBookId[bookId];

  /// קבוצת-על של הספרים שכינוי שלהם עלול להתאים ל-[normalizedQuery] — בזהות,
  /// בתחילית או בהכלה. `null` פירושו "אין צמצום, סרוק את כל הספרים".
  ///
  /// המסננת אינה מחמיצה: כל שלוש צורות ההתאמה דורשות מונח **שמכיל** את
  /// השאילתה, ומונח כזה מכיל בהכרח כל ביגרם שלה — ולכן הספר מופיע בכל רשימות
  /// הביגרמים, כולל הנדירה שבהן. שאילתה קצרה מ-2 תווים אינה ניתנת לאינדוקס.
  AcronymCandidateBooks? candidatesFor(String normalizedQuery) {
    // אינדקס ריק מול מונחים קיימים — נפילה לסריקה מלאה. קבוצה ריקה כאן
    // הייתה משתיקה כל התאמת כינויים, בלי שגיאה.
    if (!_isLoaded || _bookIdsByBigram.isEmpty) return null;
    if (normalizedQuery.length < 2) return null;

    Int32List? rarestBookIds;
    for (var i = 0; i + 1 < normalizedQuery.length; i++) {
      final bookIds =
          _bookIdsByBigram[_bigramKey(
            normalizedQuery.codeUnitAt(i),
            normalizedQuery.codeUnitAt(i + 1),
          )];
      // ביגרם שאינו במאגר — אף מונח אינו מכיל את השאילתה.
      if (bookIds == null) return _noCandidates;
      if (rarestBookIds == null || bookIds.length < rarestBookIds.length) {
        rarestBookIds = bookIds;
      }
    }
    return AcronymCandidateBooks._(rarestBookIds!);
  }

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
        _bookIdsByBigram.clear();
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

      // רק שליפת השורות חייבת לרוץ כאן (החיבור חי על ה-isolate הזה);
      // הנורמליזציה ובניית האינדקס עוברות ל-isolate כדי לא להתחרות ב-UI.
      final rawPairs = <(int, String)>[
        for (final row in acrRows)
          (row['bookId'] as int, (row['term'] as String?) ?? ''),
      ];
      final (local, bigrams) = await Isolate.run(() {
        final result = <int, List<String>>{};
        for (final (bookId, term) in rawPairs) {
          if (term.isEmpty) continue;
          final normalized = normalizeForFindRefMatch(term);
          if (normalized.isEmpty) continue;
          result.putIfAbsent(bookId, () => <String>[]).add(normalized);
        }
        return (result, _buildBigramIndex(result));
      });

      if (myGen != _generation) return;
      _acronymsByBookId
        ..clear()
        ..addAll(local);
      _bookIdsByBigram
        ..clear()
        ..addAll(bigrams);
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
        _bookIdsByBigram.clear();
      }
    }
  }

  void clear() {
    _generation++;
    _acronymsByBookId.clear();
    _bookIdsByBigram.clear();
    _isLoaded = false;
    _loadingFuture = null;
  }

  /// בדיקות בלבד — מזריק מונחים גולמיים (כמו ב-DB) ומנרמל אותם כמו הטעינה
  /// האמיתית, כדי לבדוק את מסלול ההתאמה בלי DB.
  @visibleForTesting
  void setAcronymsForTesting(Map<int, List<String>> rawTermsByBookId) {
    _acronymsByBookId.clear();
    for (final entry in rawTermsByBookId.entries) {
      final normalized = entry.value
          .map(normalizeForFindRefMatch)
          .where((t) => t.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) _acronymsByBookId[entry.key] = normalized;
    }
    _bookIdsByBigram
      ..clear()
      ..addAll(_buildBigramIndex(_acronymsByBookId));
    _isLoaded = true;
  }
}

int _bigramKey(int first, int second) => (first << 16) | second;

/// בונה את אינדקס הביגרמים מהמונחים המנורמלים. פונקציה top-level כדי שה-closure
/// של ה-`Isolate.run` לא יוכל ללכוד את ה-singleton — שאינו sendable.
///
/// המזהים נצברים בסדר עולה כדי שכל רשימה תהיה ממוינת ([AcronymCandidateBooks]
/// מסתמך על כך), ולכן די בהשוואה לאיבר האחרון לניכוי כפילויות.
Map<int, Int32List> _buildBigramIndex(
  Map<int, List<String>> acronymsByBookId,
) {
  final postings = <int, List<int>>{};
  final bookIds = acronymsByBookId.keys.toList()..sort();
  for (final bookId in bookIds) {
    for (final term in acronymsByBookId[bookId]!) {
      var previous = -1;
      for (var i = 0; i < term.length; i++) {
        final current = term.codeUnitAt(i);
        if (previous >= 0) {
          final list = postings[_bigramKey(previous, current)];
          if (list == null) {
            postings[_bigramKey(previous, current)] = <int>[bookId];
          } else if (list.last != bookId) {
            list.add(bookId);
          }
        }
        previous = current;
      }
    }
  }
  return {
    for (final entry in postings.entries)
      entry.key: Int32List.fromList(entry.value),
  };
}
