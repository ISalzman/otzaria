import 'dart:math' as math;
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/search/search_query_builder.dart';
import 'package:otzaria/search/utils/hebrew_morphology.dart';
import 'package:otzaria/search/utils/regex_patterns.dart';
import 'package:search_engine/search_engine.dart';

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
      {ResultsOrder order = ResultsOrder.relevance,
      bool fuzzy = false,
      int distance = 2,
      Map<String, String>? customSpacing,
      Map<int, List<String>>? alternativeWords,
      Map<String, Map<String, bool>>? searchOptions}) async {
    print('🚀 searchTexts called with query: "$query"');

    // בדיקת וריאציות כתיב מלא/חסר
    print('🔍 Testing spelling variations for "ראשית":');
    final testVariations =
        SearchRegexPatterns.generateFullPartialSpellingVariations('ראשית');
    print('   variations: $testVariations');

    // בדיקת createPrefixPattern עבור כל וריאציה
    for (final variation in testVariations) {
      final prefixPattern = SearchRegexPatterns.createPrefixPattern(variation);
      print('   $variation -> $prefixPattern');
    }

    // בדיקת createSpellingWithPrefixPattern
    final finalPattern =
        SearchRegexPatterns.createSpellingWithPrefixPattern('ראשית');
    print('🔍 Final createSpellingWithPrefixPattern result: $finalPattern');
    final index = await TantivyDataProvider.instance.engine;

    // בדיקה אם יש מרווחים מותאמים אישית, מילים חילופיות או אפשרויות חיפוש
    final hasCustomSpacing = customSpacing != null && customSpacing.isNotEmpty;
    final hasAlternativeWords =
        alternativeWords != null && alternativeWords.isNotEmpty;
    final hasSearchOptions = searchOptions != null &&
        searchOptions.isNotEmpty &&
        searchOptions.values.any((wordOptions) =>
            wordOptions.values.any((isEnabled) => isEnabled == true));

    print('🔍 hasSearchOptions: $hasSearchOptions');
    print('🔍 hasAlternativeWords: $hasAlternativeWords');

    // המרת החיפוש לפורמט המנוע החדש
    // סינון מחרוזות ריקות שנוצרות כאשר יש רווחים בסוף השאילתה
    final words = query
        .trim()
        .split(SearchRegexPatterns.wordSplitter)
        .where((word) => word.isNotEmpty)
        .toList();
    final List<String> regexTerms;
    final int effectiveSlop;

    // הודעת דיבוג לבדיקת search options
    if (searchOptions != null && searchOptions.isNotEmpty) {
      print('➡️Debug search options:');
      for (final entry in searchOptions.entries) {
        print('   ${entry.key}: ${entry.value}');
      }
    }

    if (hasAlternativeWords || hasSearchOptions) {
      // יש מילים חילופיות או אפשרויות חיפוש - נבנה queries מתקדמים
      print('🔄 בונה query מתקדם');
      if (hasAlternativeWords) print('🔄 מילים חילופיות: $alternativeWords');
      if (hasSearchOptions) print('🔄 אפשרויות חיפוש: $searchOptions');

      regexTerms = SearchQueryBuilder.buildAdvancedQuery(
          words, alternativeWords, searchOptions);
      print('🔄 RegexTerms מתקדם: $regexTerms');
      print(
          '🔄 effectiveSlop will be: ${hasCustomSpacing ? "custom" : (fuzzy ? distance.toString() : "0")}');
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

    print('🔍 Final search params:');
    print('   regexTerms: $regexTerms');
    print('   facets: $facets');
    print('   limit: $limit');
    print('   slop: $effectiveSlop');
    print('   maxExpansions: $maxExpansions');
    print('🚀 Calling index.search...');

    final results = await index.search(
        regexTerms: regexTerms,
        facets: facets,
        limit: limit,
        slop: effectiveSlop,
        maxExpansions: maxExpansions,
        order: order);

    print('✅ Search completed, found ${results.length} results');
    return results;
  }
}
