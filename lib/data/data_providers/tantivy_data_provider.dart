import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:search_engine/search_engine.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:hive/hive.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/search/search_query_builder.dart';

/// A singleton class that manages search functionality using Tantivy search engine.
///
/// This provider handles the search operations for both text-based and PDF books,
/// maintaining an index for full-text search capabilities.
class TantivyDataProvider {
  /// Instance of the search engine pointing to the index directory
  late Future<SearchEngine> engine;
  late ReferenceSearchEngine refEngine;

  static final TantivyDataProvider _singleton = TantivyDataProvider();
  static TantivyDataProvider instance = _singleton;

  // Global cache for facet counts
  static final Map<String, int> _globalFacetCache = {};
  static String _lastCachedQuery = '';

  // Track ongoing counts to prevent duplicates
  static final Set<String> _ongoingCounts = {};

  /// Clear global cache when starting new search
  static void clearGlobalCache() {
    print(
        '🧹 Clearing global facet cache (${_globalFacetCache.length} entries)');
    _globalFacetCache.clear();
    _ongoingCounts.clear();
    _lastCachedQuery = '';
  }

  /// Indicates whether the indexing process is currently running
  ValueNotifier<bool> isIndexing = ValueNotifier(false);

  /// Maintains a list of processed books to avoid reindexing
  late List<String> booksDone;

  TantivyDataProvider() {
    reopenIndex();
  }

  void reopenIndex() {
    String indexPath = (Settings.getValue('key-library-path') ?? 'C:/אוצריא') +
        Platform.pathSeparator +
        'index';
    String refIndexPath =
        (Settings.getValue('key-library-path') ?? 'C:/אוצריא') +
            Platform.pathSeparator +
            'ref_index';

    engine = Future.value(SearchEngine(path: indexPath));

    try {
      refEngine = ReferenceSearchEngine(path: refIndexPath);
    } catch (e) {
      if (e.toString() ==
          "PanicException(Failed to create index: SchemaError(\"An index exists but the schema does not match.\"))") {
        resetIndex(indexPath);
        reopenIndex();
      } else {
        rethrow;
      }
    }
    //test the engine
    engine.then((value) {
      try {
        // Test the search engine
        value
            .search(
                regexTerms: ['a'],
                limit: 10,
                slop: 0,
                maxExpansions: 10,
                facets: ["/"],
                order: ResultsOrder.catalogue)
            .then((results) {
          // Engine test successful
        }).catchError((e) {
          // Log engine test error
        });
      } catch (e) {
        // Log sync engine test error
        if (e.toString() ==
            "PanicException(Failed to create index: SchemaError(\"An index exists but the schema does not match.\"))") {
          resetIndex(indexPath);
          reopenIndex();
        } else {
          rethrow;
        }
      }
    });
    try {
      booksDone = Hive.box(
              name: 'books_indexed',
              directory:
                  (Settings.getValue('key-library-path') ?? 'C:/אוצריא') +
                      Platform.pathSeparator +
                      'index')
          .get('key-books-done', defaultValue: [])
          .map<String>((e) => e.toString())
          .toList() as List<String>;
    } catch (e) {
      booksDone = [];
    }
  }

  /// Persists the list of indexed books to disk using Hive storage.
  saveBooksDoneToDisk() {
    Hive.box(
            name: 'books_indexed',
            directory: (Settings.getValue('key-library-path') ?? 'C:/אוצריא') +
                Platform.pathSeparator +
                'index')
        .put('key-books-done', booksDone);
  }

  Future<int> countTexts(String query, List<String> books, List<String> facets,
      {bool fuzzy = false,
      int distance = 2,
      Map<String, String>? customSpacing,
      Map<int, List<String>>? alternativeWords,
      Map<String, Map<String, bool>>? searchOptions}) async {
    // Global cache check
    final cacheKey =
        '$query|${facets.join(',')}|$fuzzy|$distance|${customSpacing.toString()}|${alternativeWords.toString()}|${searchOptions.toString()}';

    if (_lastCachedQuery == query && _globalFacetCache.containsKey(cacheKey)) {
      print('🎯 GLOBAL CACHE HIT for $facets: ${_globalFacetCache[cacheKey]}');
      return _globalFacetCache[cacheKey]!;
    }

    // Check if this count is already in progress
    if (_ongoingCounts.contains(cacheKey)) {
      print('⏳ Count already in progress for $facets, waiting...');
      // Wait for the ongoing count to complete
      while (_ongoingCounts.contains(cacheKey)) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (_globalFacetCache.containsKey(cacheKey)) {
          print(
              '🎯 DELAYED CACHE HIT for $facets: ${_globalFacetCache[cacheKey]}');
          return _globalFacetCache[cacheKey]!;
        }
      }
    }

    // Mark this count as in progress
    _ongoingCounts.add(cacheKey);
    final index = await engine;

    // בדיקה אם יש מרווחים מותאמים אישית, מילים חילופיות או אפשרויות חיפוש
    final hasCustomSpacing = customSpacing != null && customSpacing.isNotEmpty;
    final hasAlternativeWords =
        alternativeWords != null && alternativeWords.isNotEmpty;
    final hasSearchOptions = searchOptions != null && searchOptions.isNotEmpty;

    // המרת החיפוש לפורמט המנוע החדש - בדיוק כמו ב-SearchRepository!
    final words = query.trim().split(RegExp(r'\s+'));
    final List<String> regexTerms;
    final int effectiveSlop;

    if (hasAlternativeWords || hasSearchOptions) {
      // יש מילים חילופיות או אפשרויות חיפוש - נבנה queries מתקדמים
      regexTerms = SearchQueryBuilder.buildAdvancedQuery(
          words, alternativeWords, searchOptions);
      effectiveSlop = hasCustomSpacing
          ? SearchQueryBuilder.getMaxCustomSpacing(customSpacing, words.length)
          : (fuzzy ? distance : 0);
    } else if (fuzzy) {
      // חיפוש מקורב - נשתמש במילים בודדות
      regexTerms = words;
      effectiveSlop = distance;
    } else if (words.length == 1) {
      // מילה אחת - חיפוש פשוט
      regexTerms = [query];
      effectiveSlop = 0;
    } else if (hasCustomSpacing) {
      // מרווחים מותאמים אישית
      regexTerms = words;
      effectiveSlop =
          SearchQueryBuilder.getMaxCustomSpacing(customSpacing, words.length);
    } else {
      // חיפוש מדוייק של כמה מילים
      regexTerms = words;
      effectiveSlop = distance;
    }

    // חישוב maxExpansions בהתבסס על סוג החיפוש
    final int maxExpansions = SearchQueryBuilder.calculateMaxExpansions(
        fuzzy, regexTerms.length,
        searchOptions: searchOptions, words: words);

    try {
      final count = await index.count(
          regexTerms: regexTerms,
          facets: facets,
          slop: effectiveSlop,
          maxExpansions: maxExpansions);

      // Save to global cache
      _lastCachedQuery = query;
      _globalFacetCache[cacheKey] = count;
      _ongoingCounts.remove(cacheKey); // Mark as completed
      print('💾 GLOBAL CACHE SAVE for $facets: $count');

      return count;
    } catch (e) {
      // Remove from ongoing counts even on error
      _ongoingCounts.remove(cacheKey);
      // Log error in production
      rethrow;
    }
  }

  Future<void> resetIndex(String indexPath) async {
    Directory indexDirectory = Directory(indexPath);
    Hive.box(name: 'books_indexed', directory: indexPath).close();
    indexDirectory.deleteSync(recursive: true);
    indexDirectory.createSync(recursive: true);
  }

  /// Performs an asynchronous stream-based search operation across indexed texts.
  ///
  /// [query] The search query string
  /// [books] List of book identifiers to search within
  /// [limit] Maximum number of results to return
  /// [fuzzy] Whether to perform fuzzy matching
  ///
  /// Returns a Stream of search results that can be listened to for real-time updates
  Stream<List<SearchResult>> searchTextsStream(
      String query, List<String> facets, int limit, bool fuzzy) async* {
    // הפונקציה הזו לא נתמכת במנוע החדש - נחזיר תוצאה חד-פעמית
    final searchRepository = SearchRepository();
    final results =
        await searchRepository.searchTexts(query, facets, limit, fuzzy: fuzzy);
    yield results;
  }

  Future<List<ReferenceSearchResult>> searchRefs(
      String reference, int limit, bool fuzzy) async {
    return refEngine.search(
        query: reference,
        limit: limit,
        fuzzy: fuzzy,
        order: ResultsOrder.relevance);
  }

  /// ספירה מקבצת של תוצאות עבור מספר facets בבת אחת - לשיפור ביצועים
  Future<Map<String, int>> countTextsForMultipleFacets(
      String query, List<String> books, List<String> facets,
      {bool fuzzy = false,
      int distance = 2,
      Map<String, String>? customSpacing,
      Map<int, List<String>>? alternativeWords,
      Map<String, Map<String, bool>>? searchOptions}) async {
    print(
        '🔍 TantivyDataProvider: Starting batch count for ${facets.length} facets');
    final stopwatch = Stopwatch()..start();

    final index = await engine;
    final results = <String, int>{};

    // בדיקה אם יש מרווחים מותאמים אישית, מילים חילופיות או אפשרויות חיפוש
    final hasCustomSpacing = customSpacing != null && customSpacing.isNotEmpty;
    final hasAlternativeWords =
        alternativeWords != null && alternativeWords.isNotEmpty;
    final hasSearchOptions = searchOptions != null && searchOptions.isNotEmpty;

    // המרת החיפוש לפורמט המנוע החדש - בדיוק כמו ב-countTexts
    final words = query.trim().split(RegExp(r'\s+'));
    final List<String> regexTerms;
    final int effectiveSlop;

    if (hasAlternativeWords || hasSearchOptions) {
      regexTerms = SearchQueryBuilder.buildAdvancedQuery(
          words, alternativeWords, searchOptions);
      effectiveSlop = hasCustomSpacing
          ? SearchQueryBuilder.getMaxCustomSpacing(customSpacing, words.length)
          : (fuzzy ? distance : 0);
    } else if (fuzzy) {
      regexTerms = words;
      effectiveSlop = distance;
    } else if (words.length == 1) {
      regexTerms = [query];
      effectiveSlop = 0;
    } else if (hasCustomSpacing) {
      regexTerms = words;
      effectiveSlop =
          SearchQueryBuilder.getMaxCustomSpacing(customSpacing, words.length);
    } else {
      regexTerms = words;
      effectiveSlop = distance;
    }

    final int maxExpansions = SearchQueryBuilder.calculateMaxExpansions(
        fuzzy, regexTerms.length,
        searchOptions: searchOptions, words: words);

    // ביצוע ספירה עבור כל facet - בזה אחר זה (לא במקביל כי זה לא עובד)
    int processedCount = 0;
    int zeroResultsCount = 0;

    for (final facet in facets) {
      try {
        print(
            '🔍 Counting facet: $facet (${processedCount + 1}/${facets.length})');
        final facetStopwatch = Stopwatch()..start();
        final count = await index.count(
            regexTerms: regexTerms,
            facets: [facet],
            slop: effectiveSlop,
            maxExpansions: maxExpansions);
        facetStopwatch.stop();
        print(
            '✅ Facet $facet: $count (${facetStopwatch.elapsedMilliseconds}ms)');
        results[facet] = count;

        processedCount++;
        if (count == 0) {
          zeroResultsCount++;
        }

        // אם יש יותר מדי facets עם 0 תוצאות, נפסיק מוקדם
        if (processedCount >= 10 && zeroResultsCount > processedCount * 0.8) {
          print('⚠️ Too many zero results, stopping early');
          // נמלא את השאר עם 0
          for (int i = processedCount; i < facets.length; i++) {
            results[facets[i]] = 0;
          }
          break;
        }
      } catch (e) {
        print('❌ Error counting facet $facet: $e');
        results[facet] = 0;
        processedCount++;
        zeroResultsCount++;
      }
    }

    stopwatch.stop();
    print(
        '✅ TantivyDataProvider: Batch count completed in ${stopwatch.elapsedMilliseconds}ms');
    print(
        '📊 Results: ${results.entries.where((e) => e.value > 0).map((e) => '${e.key}: ${e.value}').join(', ')}');

    return results;
  }

  /// Clears the index and resets the list of indexed books.
  Future<void> clear() async {
    isIndexing.value = false;
    final index = await engine;
    await index.clear();
    final refIndex = refEngine;
    await refIndex.clear();
    booksDone.clear();
    saveBooksDoneToDisk();
  }
}
