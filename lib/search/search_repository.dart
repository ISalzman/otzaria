import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/search_query_builder.dart';
import 'package:search_engine/search_engine.dart';
import 'package:flutter/foundation.dart';

/// Performs a search operation across indexed texts.
///
/// [query] The search query string
/// [facets] List of facets to search within
/// [limit] Maximum number of results to return
/// [order] Sort order for results
/// [fuzzy] Whether to perform fuzzy matching
/// [distance] Default distance between words (slop)
/// [customSpacing] Custom spacing between specific word pairs
/// [alternativeWords] Alternative words for each word position (OR queries)
/// [searchOptions] Search options for each word (prefixes, suffixes, etc.)
///
/// Returns a Future containing a list of search results
///
class SearchRepository {
  Future<List<SearchResult>> searchTexts(
      String query, List<String> facets, int limit,
      {int offset = 0,
      ResultsOrder order = ResultsOrder.relevance,
      bool fuzzy = false,
      int distance = 0,
      SearchMode searchMode = SearchMode.exact,
      Map<String, String>? customSpacing,
      Map<int, List<String>>? alternativeWords,
      Map<String, Map<String, bool>>? searchOptions}) async {
    final index = await TantivyDataProvider.instance.engine;
    final normalizedParameters = SearchQueryBuilder.normalizeParametersForMode(
      searchMode,
      customSpacing: customSpacing,
      alternativeWords: alternativeWords,
      searchOptions: searchOptions,
    );

    // בדיקה אם יש מרווחים מותאמים אישית, מילים חילופיות או אפשרויות חיפוש
    final hasCustomSpacing = normalizedParameters.customSpacing.isNotEmpty;
    final hasAlternativeWords =
        normalizedParameters.alternativeWords.isNotEmpty;
    debugPrint('🔍 hasCustomSpacing: $hasCustomSpacing');
    final hasSearchOptions = SearchQueryBuilder.hasEnabledSearchOptions(
        normalizedParameters.searchOptions);

    debugPrint('🔍 hasSearchOptions: $hasSearchOptions');
    debugPrint('🔍 hasAlternativeWords: $hasAlternativeWords');

    // המרת החיפוש לפורמט המנוע החדש
    debugPrint('🔍 Using prepareQueryParams');
    final params = SearchQueryBuilder.prepareQueryParams(
      query,
      fuzzy,
      distance,
      normalizedParameters.customSpacing,
      normalizedParameters.alternativeWords,
      normalizedParameters.searchOptions,
    );
    final List<String> regexTerms = params['regexTerms'] as List<String>;
    final int effectiveSlop = params['effectiveSlop'] as int;
    final int maxExpansions = params['maxExpansions'] as int;

    debugPrint('🔍 Final search params:');
    debugPrint('   regexTerms: $regexTerms');
    debugPrint('   facets: $facets');
    debugPrint('   limit: $limit');
    debugPrint('   offset: $offset');
    debugPrint('   slop: $effectiveSlop');
    debugPrint('   maxExpansions: $maxExpansions');
    debugPrint('🚀 Calling index.search...');

    final results = await index.search(
        regexTerms: regexTerms,
        facets: facets,
        limit: limit,
        offset: offset,
        slop: effectiveSlop,
        maxExpansions: maxExpansions,
        order: order);

    debugPrint('✅ Search completed, found ${results.length} results');
    return results;
  }

  /// Performs a combined search + count in a single engine pass.
  /// Returns total hit count alongside paged results, without streaming.
  /// Prefer this over separate search() + count() calls when streaming is not needed.
  ///
  /// [query] The search query string
  /// [facets] List of facets to search within
  /// [limit] Maximum number of results to return
  ///
  /// Returns a Future containing [SearchPageResult] with results and totalCount
  Future<SearchPageResult> searchTextsAndCount(
      String query, List<String> facets, int limit,
      {int offset = 0,
      ResultsOrder order = ResultsOrder.relevance,
      bool fuzzy = false,
      int distance = 0,
      SearchMode searchMode = SearchMode.exact,
      Map<String, String>? customSpacing,
      Map<int, List<String>>? alternativeWords,
      Map<String, Map<String, bool>>? searchOptions}) async {
    final index = await TantivyDataProvider.instance.engine;
    final normalizedParameters = SearchQueryBuilder.normalizeParametersForMode(
      searchMode,
      customSpacing: customSpacing,
      alternativeWords: alternativeWords,
      searchOptions: searchOptions,
    );

    final params = SearchQueryBuilder.prepareQueryParams(
      query,
      fuzzy,
      distance,
      normalizedParameters.customSpacing,
      normalizedParameters.alternativeWords,
      normalizedParameters.searchOptions,
    );
    final List<String> regexTerms = params['regexTerms'] as List<String>;
    final int effectiveSlop = params['effectiveSlop'] as int;
    final int maxExpansions = params['maxExpansions'] as int;

    debugPrint('🔍 searchTextsAndCount:');
    debugPrint('   regexTerms: $regexTerms');
    debugPrint('   facets: $facets, limit: $limit, offset: $offset');

    final result = await index.searchAndCount(
        regexTerms: regexTerms,
        facets: facets,
        limit: limit,
        offset: offset,
        slop: effectiveSlop,
        maxExpansions: maxExpansions,
        order: order);

    debugPrint(
        '✅ searchAndCount: ${result.results.length} results / ${result.totalCount} total');
    return result;
  }

  /// Performs a streaming search operation across indexed texts.
  /// Results are returned in chunks for better UX with large result sets.
  ///
  /// [query] The search query string
  /// [facets] List of facets to search within
  /// [limit] Maximum number of results to return
  /// [chunkSize] Number of results per chunk (default: 50)
  /// [order] Sort order for results
  /// [fuzzy] Whether to perform fuzzy matching
  /// [distance] Default distance between words (slop)
  /// [customSpacing] Custom spacing between specific word pairs
  /// [alternativeWords] Alternative words for each word position (OR queries)
  /// [searchOptions] Search options for each word (prefixes, suffixes, etc.)
  ///
  /// Returns a Stream of search result chunks
  ///
  Stream<List<SearchResult>> searchTextsStream(
      String query, List<String> facets, int limit,
      {int offset = 0,
      int chunkSize = 50,
      ResultsOrder order = ResultsOrder.relevance,
      bool fuzzy = false,
      int distance = 0,
      SearchMode searchMode = SearchMode.exact,
      Map<String, String>? customSpacing,
      Map<int, List<String>>? alternativeWords,
      Map<String, Map<String, bool>>? searchOptions}) async* {
    final index = await TantivyDataProvider.instance.engine;
    final normalizedParameters = SearchQueryBuilder.normalizeParametersForMode(
      searchMode,
      customSpacing: customSpacing,
      alternativeWords: alternativeWords,
      searchOptions: searchOptions,
    );

    // המרת החיפוש לפורמט המנוע החדש
    final params = SearchQueryBuilder.prepareQueryParams(
      query,
      fuzzy,
      distance,
      normalizedParameters.customSpacing,
      normalizedParameters.alternativeWords,
      normalizedParameters.searchOptions,
    );
    final List<String> regexTerms = params['regexTerms'] as List<String>;
    final int effectiveSlop = params['effectiveSlop'] as int;
    final int maxExpansions = params['maxExpansions'] as int;

    debugPrint('🔍 Starting streaming search:');
    debugPrint('   regexTerms: $regexTerms');
    debugPrint('   facets: $facets');
    debugPrint('   limit: $limit');
    debugPrint('   offset: $offset');
    debugPrint('   chunkSize: $chunkSize');
    debugPrint('   slop: $effectiveSlop');
    debugPrint('   maxExpansions: $maxExpansions');

    final stream = index.searchStream(
      regexTerms: regexTerms,
      facets: facets,
      limit: limit,
      offset: offset,
      slop: effectiveSlop,
      maxExpansions: maxExpansions,
      order: order,
      chunkSize: chunkSize,
    );

    await for (final chunk in stream) {
      debugPrint('📦 Received chunk of ${chunk.length} results');
      yield chunk;
    }

    debugPrint('✅ Streaming search completed');
  }
}
