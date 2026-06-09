import 'dart:isolate';

import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/indexing/bloc/indexing_bloc.dart';
import 'package:otzaria/indexing/bloc/indexing_event.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/utils/text/text_manipulation.dart';

/// DataRepository acts as a centralized data access layer that coordinates between different
/// data providers (file system, Hive storage, and Tantivy search engine).
///
/// This repository implements the Repository pattern to abstract the data source
/// implementation details from the business logic. It provides a clean API for
/// accessing and manipulating application data from various sources.
class DataRepository {
  /// Handles file system operations like reading book texts and metadata
  final FileSystemData _fileSystemData = FileSystemData.instance;

  /// Singleton instance of the DataRepository
  static final DataRepository _singleton = DataRepository();

  /// Provides access to the singleton instance
  static DataRepository get instance => _singleton;

  Future<Library>? _libraryFuture;
  Future<Library> get library => _libraryFuture ??= _getLibrary();
  set library(Future<Library> value) => _libraryFuture = value;

  // Lazy-loaded: only fetched when user actually searches for external books.
  // Previously these ran getAllBooksWithRelations() eagerly at startup,
  // competing with library loading for DB I/O.
  Future<List<Book>>? _hebrewBooksFuture;
  Future<List<Book>>? _localHebrewBooksFuture;
  Future<List<ExternalLibraryBook>>? _otzarBooksFuture;
  Future<List<Book>> get hebrewBooks => _hebrewBooksFuture ??= getHebrewBooks();

  /// ספרי היברובוקס שקיים להם PDF מקומי (כ-[PdfBook]). נחשבים מקומיים
  /// ומוצגים בחיפוש גם כשהצגת ספרים חיצוניים כבויה.
  Future<List<Book>> get localHebrewBooks =>
      _localHebrewBooksFuture ??= FileSystemData.getLocalHebrewBooks();
  Future<List<ExternalLibraryBook>> get otzarBooks =>
      _otzarBooksFuture ??= getOtzarBooks();

  /// Invalidates cached external books so they are re-fetched on next access.
  /// Call this when the library is refreshed.
  void invalidateExternalBooksCache() {
    _hebrewBooksFuture = null;
    _localHebrewBooksFuture = null;
    _otzarBooksFuture = null;
  }

  DataRepository();

  /// Retrieves the complete library metadata including all available books
  ///
  /// Returns a [Future] that completes with a [Library] object containing
  /// the full library structure and metadata
  Future<Library> _getLibrary() async {
    return _fileSystemData.getLibrary();
  }

  /// Retrieves the list of books from the Otzar HaHochma project
  ///
  /// Returns a [Future] that completes with a list of [ExternalLibraryBook] objects
  /// representing books from the Otzar HaHochma collection
  Future<List<ExternalLibraryBook>> getOtzarBooks() {
    return FileSystemData.getOtzarBooks();
  }

  /// Retrieves the list of books from the Hebrew Books project
  ///
  /// Returns a [Future] that completes with a list of [Book] objects
  /// representing books from the Hebrew Books collection
  Future<List<Book>> getHebrewBooks() {
    return FileSystemData.getHebrewBooks();
  }

  /// Retrieves the full text content of a specific book
  ///
  /// Parameters:
  ///   - [title]: The title of the book to retrieve
  ///
  /// Returns a [Future] that completes with the book's text content as a [String]
  Future<String> getBookText(String title,
      {int? categoryId, String? fileType}) async {
    return _fileSystemData.getBookText(title,
        categoryId: categoryId, fileType: fileType);
  }

  /// Retrieves the table of contents for a specific book
  ///
  /// Parameters:
  ///   - [title]: The title of the book whose TOC should be retrieved
  ///
  /// Returns a [Future] that completes with a list of [TocEntry] objects
  /// representing the book's table of contents structure
  Future<List<TocEntry>> getBookToc(String title,
      {int? categoryId, String? fileType}) async {
    return _fileSystemData.getBookToc(title,
        categoryId: categoryId, fileType: fileType);
  }

  /// Searches for references by relevance to a given reference string
  ///
  /// Parameters:
  ///   - [ref]: The reference string to search for
  ///   - [limit]: Maximum number of results to return (defaults to 10)
  ///
  /// Returns a [Future] that completes with a list of [Ref] objects sorted by relevance

  /// Adds text content from the library to the Tantivy search index
  ///
  /// Parameters:
  ///   - [library]: The library containing books to index
  ///
  /// This method now uses the IndexingBloc to handle the indexing process
  Future<void> addAllTextsToTantivy(
    Library library,
  ) async {
    // Create an instance of IndexingBloc
    final indexingBloc = IndexingBloc.create();

    // Start the indexing process
    indexingBloc.add(StartIndexing(library));
  }

  /// Searches for books based on query text and optional filters
  ///
  /// Parameters:
  ///   - [query]: The search text to match against book titles
  ///   - [category]: Optional category to filter results
  ///   - [topics]: Optional list of topics to filter results
  ///   - [includeOtzar]: Whether to include Otzar HaChochma books
  ///   - [includeHebrewBooks]: Whether to include HebrewBooks.org books
  ///
  /// Returns a [Future] that completes with a list of [Book] objects matching the criteria
  Future<List<Book>> findBooks(
    String query,
    Category? category, {
    List<String>? topics,
    bool includeOtzar = false,
    bool includeHebrewBooks = false,
    bool sortByRatio = true,
  }) async {
    final normalizedQuery = _normalizeForSearch(query);
    final queryWords = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (queryWords.isEmpty) {
      return [];
    }

    final allBooks = <Book>[
      ...(category?.getAllBooks() ?? (await library).getAllBooks()),
    ];

    if (includeOtzar) {
      allBooks.addAll(await otzarBooks);
    }
    if (includeHebrewBooks) {
      allBooks.addAll(await hebrewBooks);
    } else {
      // ספרי היברובוקס שיש להם PDF מקומי הם ספרים שכבר נמצאים במחשב,
      // ולכן מוצגים תמיד — גם כשהצגת ספרים חיצוניים כבויה.
      allBooks.addAll(await localHebrewBooks);
    }

    final searchEntries = <_BookSearchEntry>[
      for (var i = 0; i < allBooks.length; i++)
        _BookSearchEntry(
          index: i,
          title: allBooks[i].title,
          author: allBooks[i].author ?? '',
          topics: allBooks[i].topics,
        ),
    ];

    final matchingIndices = await Isolate.run(
      () => _filterBookSearchEntries(
        entries: searchEntries,
        queryWords: queryWords,
        topics: topics ?? const <String>[],
        sortByRatio: sortByRatio,
        normalizedQuery: normalizedQuery,
      ),
    );

    return [
      for (final index in matchingIndices) allBooks[index],
    ];
  }

  String _normalizeForSearch(String input) {
    var cleaned = removeTeamim(removeVolwels(input));
    cleaned = cleaned.replaceAll('"', '').replaceAll("'", '');
    cleaned = cleaned.replaceAll('\u05F4', '').replaceAll('\u05F3', '');
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\u0590-\u05FF\s]'), ' ');
    return cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _BookSearchEntry {
  final int index;
  final String title;
  final String author;
  final String topics;

  const _BookSearchEntry({
    required this.index,
    required this.title,
    required this.author,
    required this.topics,
  });
}

List<int> _filterBookSearchEntries({
  required List<_BookSearchEntry> entries,
  required List<String> queryWords,
  required List<String> topics,
  required bool sortByRatio,
  required String normalizedQuery,
}) {
  final preparedEntries = entries.map((entry) {
    final normalizedTitle = _normalizeBookSearchText(entry.title);
    final normalizedAuthor = _normalizeBookSearchText(entry.author);
    final topics = entry.topics
        .split(',')
        .map((topic) => topic.trim())
        .where((topic) => topic.isNotEmpty)
        .toSet();

    return _PreparedBookSearchEntry(
      index: entry.index,
      normalizedTitle: normalizedTitle,
      normalizedAuthor: normalizedAuthor,
      topics: topics,
    );
  });

  // Damerau-Levenshtein edit distance (supports transposition of adjacent chars)
  // e.g. אבועלפיה → אבולעפיה counts as 1 edit, not 2
  int editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final aChars = a.runes.toList();
    final bChars = b.runes.toList();
    final la = aChars.length;
    final lb = bChars.length;
    // d[i][j] = distance between a[0..i-1] and b[0..j-1]
    final d = List.generate(
        la + 1, (i) => List<int>.generate(lb + 1, (j) => j == 0 ? i : 0));
    for (int j = 0; j <= lb; j++) {
      d[0][j] = j;
    }
    for (int i = 1; i <= la; i++) {
      for (int j = 1; j <= lb; j++) {
        final cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1, // deletion
          d[i][j - 1] + 1, // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
        // transposition of two adjacent characters
        if (i > 1 &&
            j > 1 &&
            aChars[i - 1] == bChars[j - 2] &&
            aChars[i - 2] == bChars[j - 1]) {
          d[i][j] = d[i][j] < d[i - 2][j - 2] + cost
              ? d[i][j]
              : d[i - 2][j - 2] + cost;
        }
      }
    }
    return d[la][lb];
  }

  // Allowed edit distance by query word length:
  // 1-4  chars → 0 (exact)
  // 4-8  chars → 1 typo
  // 8-12 chars → 2 typos
  // 12-16 chars → 3 typos
  // 16+  chars → 4 typos
  int maxAllowedEdits(int len) {
    if (len <= 4) return 0;
    if (len <= 8) return 1;
    if (len <= 12) return 2;
    if (len <= 16) return 3;
    return 4;
  }

  bool wordMatchesFuzzy(String queryWord, String text) {
    if (text.contains(queryWord)) return true;
    if (queryWord.length < 3) return false;

    final allowed = maxAllowedEdits(queryWord.length);
    final textWords = text.split(' ');
    for (final textWord in textWords) {
      if (textWord.isEmpty) continue;
      // Only compare words of similar length to avoid false positives
      if ((textWord.length - queryWord.length).abs() > allowed + 1) continue;
      if (editDistance(queryWord, textWord) <= allowed) return true;
    }
    return false;
  }

  final filtered = preparedEntries.where((entry) {
    final matchesQuery = queryWords.every(
      (word) =>
          wordMatchesFuzzy(word, entry.normalizedTitle) ||
          wordMatchesFuzzy(word, entry.normalizedAuthor),
    );
    final matchesTopics =
        topics.isEmpty || topics.every((topic) => entry.topics.contains(topic));

    return matchesQuery && matchesTopics;
  }).toList();

  if (sortByRatio) {
    final scored = [
      for (final entry in filtered)
        _ScoredBookSearchEntry(
          index: entry.index,
          // Boost exact matches significantly in scoring
          score: entry.normalizedTitle.contains(normalizedQuery)
              ? 100
              : ratio(normalizedQuery, entry.normalizedTitle),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    return [
      for (final entry in scored) entry.index,
    ];
  }

  return [
    for (final entry in filtered) entry.index,
  ];
}

class _PreparedBookSearchEntry {
  final int index;
  final String normalizedTitle;
  final String normalizedAuthor;
  final Set<String> topics;

  const _PreparedBookSearchEntry({
    required this.index,
    required this.normalizedTitle,
    required this.normalizedAuthor,
    required this.topics,
  });
}

class _ScoredBookSearchEntry {
  final int index;
  final int score;

  const _ScoredBookSearchEntry({
    required this.index,
    required this.score,
  });
}

String _normalizeBookSearchText(String input) {
  var cleaned = removeTeamim(removeVolwels(input));
  cleaned = cleaned.replaceAll('"', '').replaceAll("'", '');
  cleaned = cleaned.replaceAll('\u05F4', '').replaceAll('\u05F3', '');
  cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\u0590-\u05FF\s]'), ' ');
  return cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
