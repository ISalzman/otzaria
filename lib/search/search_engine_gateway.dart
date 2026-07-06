import 'dart:async';

import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as text_utils;
import 'package:otzaria_search_engine/otzaria_search_engine.dart';

/// בקשת חיפוש אחידה שמגיעה משכבת האפליקציה אל מנוע החיפוש.
///
/// המחלקה מכילה את בחירות ה-UI והניווט בלבד. מנוע החיפוש אחראי לכל
/// המשמעות האלגוריתמית של סוגי החיפוש.
class SearchEngineRequest {
  final String query;
  final List<String> facets;
  final int limit;
  final int offset;
  final ResultsOrder order;
  final SearchMode searchMode;
  final int distance;
  final Map<String, String> customSpacing;
  final Map<int, List<String>> alternativeWords;
  final Map<String, Map<String, bool>> searchOptions;

  const SearchEngineRequest({
    required this.query,
    required this.facets,
    this.limit = 0,
    this.offset = 0,
    this.order = ResultsOrder.relevance,
    this.searchMode = SearchMode.exact,
    this.distance = 0,
    this.customSpacing = const {},
    this.alternativeWords = const {},
    this.searchOptions = const {},
  });

  SearchEngineRequest copyWith({
    String? query,
    List<String>? facets,
    int? limit,
    int? offset,
    ResultsOrder? order,
    SearchMode? searchMode,
    int? distance,
    Map<String, String>? customSpacing,
    Map<int, List<String>>? alternativeWords,
    Map<String, Map<String, bool>>? searchOptions,
  }) {
    return SearchEngineRequest(
      query: query ?? this.query,
      facets: facets ?? this.facets,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      order: order ?? this.order,
      searchMode: searchMode ?? this.searchMode,
      distance: distance ?? this.distance,
      customSpacing: customSpacing ?? this.customSpacing,
      alternativeWords: alternativeWords ?? this.alternativeWords,
      searchOptions: searchOptions ?? this.searchOptions,
    );
  }
}

/// ממשק קטן וניתן לבדיקה מעל ה-API של `search_engine`.
abstract class SearchEngineOperations {
  Future<List<SearchResult>> searchExact(SearchEngineRequest request);
  Future<List<SearchResult>> searchAdvanced(SearchEngineRequest request);
  Future<List<SearchResult>> searchFuzzy(SearchEngineRequest request);

  Future<SearchPageResult> searchAndCountExact(SearchEngineRequest request);
  Future<SearchPageResult> searchAndCountAdvanced(SearchEngineRequest request);
  Future<SearchPageResult> searchAndCountFuzzy(SearchEngineRequest request);

  Stream<List<SearchResult>> searchExactStream(
    SearchEngineRequest request, {
    required int chunkSize,
  });
  Stream<List<SearchResult>> searchAdvancedStream(
    SearchEngineRequest request, {
    required int chunkSize,
  });
  Stream<List<SearchResult>> searchFuzzyStream(
    SearchEngineRequest request, {
    required int chunkSize,
  });

  Future<int> countExact(SearchEngineRequest request);
  Future<int> countAdvanced(SearchEngineRequest request);
  Future<int> countFuzzy(SearchEngineRequest request);

  Future<Map<String, int>> countByBookExact(SearchEngineRequest request);
  Future<Map<String, int>> countByBookAdvanced(SearchEngineRequest request);
  Future<Map<String, int>> countByBookFuzzy(SearchEngineRequest request);

  Future<List<FacetCount>> getFacetCountsExact(
    SearchEngineRequest request, {
    required String facetPrefix,
  });
  Future<List<FacetCount>> getFacetCountsAdvanced(
    SearchEngineRequest request, {
    required String facetPrefix,
  });
  Future<List<FacetCount>> getFacetCountsFuzzy(
    SearchEngineRequest request, {
    required String facetPrefix,
  });

  /// מזין מראש את תבנית הדגשת-הספר-הפתוח מבוססת-האינדקס לפרמטרי החיפוש —
  /// כך שכשהמשתמש יפתח תוצאה, `utils.highLight` ימצא תבנית שמדגישה את
  /// הווריאנטים שהחיפוש באמת התאים (שגיאות כתיב, קידומות, חלק ממילה).
  /// Fire-and-forget; ברירת מחדל ריקה למימושי בדיקות.
  void primeHighlightPattern(SearchEngineRequest request) {}

  /// Stream חיפוש משולב: האירוע הראשון נושא את הספירה הכוללת ואת הספירה
  /// לפי ספר, ואחריו מגיעים chunks של תוצאות. במימוש ה-Rust כל אלה מחושבים
  /// במעבר אינדקס אחד — במקום שלוש ריצות נפרדות של אותה שאילתה (stream +
  /// count + countByBook).
  ///
  /// ברירת המחדל כאן מרכיבה את אותה סמנטיקה מהמתודות הקיימות, כך שמימושי
  /// בדיקות קיימים ממשיכים לעבוד בלי לממש את המתודה.
  Stream<SearchStreamUpdate> searchStreamWithCounts(
    SearchEngineRequest request, {
    required int chunkSize,
  }) async* {
    final Map<String, int> byBook = switch (request.searchMode) {
      SearchMode.exact => await countByBookExact(request),
      SearchMode.advanced => await countByBookAdvanced(request),
      SearchMode.fuzzy => await countByBookFuzzy(request),
    };
    yield SearchStreamUpdate(
      totalCount: byBook.values.fold<int>(0, (sum, count) => sum + count),
      bookCounts: byBook,
      results: const [],
      // This compatibility fallback runs the separate count/stream calls and
      // has no visibility into single-word budget truncation; the real Rust
      // stream surfaces it.
      truncated: false,
    );
    final chunks = switch (request.searchMode) {
      SearchMode.exact => searchExactStream(request, chunkSize: chunkSize),
      SearchMode.advanced =>
        searchAdvancedStream(request, chunkSize: chunkSize),
      SearchMode.fuzzy => searchFuzzyStream(request, chunkSize: chunkSize),
    };
    await for (final chunk in chunks) {
      yield SearchStreamUpdate(results: chunk, truncated: false);
    }
  }
}

class RustSearchEngineOperations implements SearchEngineOperations {
  final SearchEngine _engine;

  const RustSearchEngineOperations(this._engine);

  @override
  Future<List<SearchResult>> searchExact(SearchEngineRequest request) {
    return _engine.searchExact(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      order: request.order,
    );
  }

  @override
  Future<List<SearchResult>> searchAdvanced(SearchEngineRequest request) {
    return _engine.searchAdvanced(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      distance: request.distance,
      customSpacing: request.customSpacing,
      alternativeWords: request.alternativeWords,
      searchOptions: request.searchOptions,
      order: request.order,
    );
  }

  @override
  Future<List<SearchResult>> searchFuzzy(SearchEngineRequest request) {
    return _engine.searchFuzzy(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      maxDistance: _fuzzyDistance(request.distance),
      order: request.order,
    );
  }

  @override
  Future<SearchPageResult> searchAndCountExact(SearchEngineRequest request) {
    return _engine.searchAndCountExact(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      order: request.order,
    );
  }

  @override
  Future<SearchPageResult> searchAndCountAdvanced(
    SearchEngineRequest request,
  ) {
    return _engine.searchAndCountAdvanced(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      distance: request.distance,
      customSpacing: request.customSpacing,
      alternativeWords: request.alternativeWords,
      searchOptions: request.searchOptions,
      order: request.order,
    );
  }

  @override
  Future<SearchPageResult> searchAndCountFuzzy(SearchEngineRequest request) {
    return _engine.searchAndCountFuzzy(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      maxDistance: _fuzzyDistance(request.distance),
      order: request.order,
    );
  }

  @override
  Stream<List<SearchResult>> searchExactStream(
    SearchEngineRequest request, {
    required int chunkSize,
  }) {
    return _engine.searchExactStream(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      order: request.order,
      chunkSize: chunkSize,
    );
  }

  @override
  Stream<List<SearchResult>> searchAdvancedStream(
    SearchEngineRequest request, {
    required int chunkSize,
  }) {
    return _engine.searchAdvancedStream(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      distance: request.distance,
      customSpacing: request.customSpacing,
      alternativeWords: request.alternativeWords,
      searchOptions: request.searchOptions,
      order: request.order,
      chunkSize: chunkSize,
    );
  }

  @override
  Stream<List<SearchResult>> searchFuzzyStream(
    SearchEngineRequest request, {
    required int chunkSize,
  }) {
    return _engine.searchFuzzyStream(
      query: request.query,
      facets: request.facets,
      limit: request.limit,
      offset: request.offset,
      maxDistance: _fuzzyDistance(request.distance),
      order: request.order,
      chunkSize: chunkSize,
    );
  }

  @override
  Future<int> countExact(SearchEngineRequest request) {
    return _engine.countExact(
      query: request.query,
      facets: request.facets,
    );
  }

  @override
  Future<int> countAdvanced(SearchEngineRequest request) {
    return _engine.countAdvanced(
      query: request.query,
      facets: request.facets,
      distance: request.distance,
      customSpacing: request.customSpacing,
      alternativeWords: request.alternativeWords,
      searchOptions: request.searchOptions,
    );
  }

  @override
  Future<int> countFuzzy(SearchEngineRequest request) {
    return _engine.countFuzzy(
      query: request.query,
      facets: request.facets,
      maxDistance: _fuzzyDistance(request.distance),
    );
  }

  @override
  Future<Map<String, int>> countByBookExact(SearchEngineRequest request) {
    return _engine.countByBookExact(
      query: request.query,
      facets: request.facets,
    );
  }

  @override
  Future<Map<String, int>> countByBookAdvanced(SearchEngineRequest request) {
    return _engine.countByBookAdvanced(
      query: request.query,
      facets: request.facets,
      distance: request.distance,
      customSpacing: request.customSpacing,
      alternativeWords: request.alternativeWords,
      searchOptions: request.searchOptions,
    );
  }

  @override
  Future<Map<String, int>> countByBookFuzzy(SearchEngineRequest request) {
    return _engine.countByBookFuzzy(
      query: request.query,
      facets: request.facets,
      maxDistance: _fuzzyDistance(request.distance),
    );
  }

  @override
  Future<List<FacetCount>> getFacetCountsExact(
    SearchEngineRequest request, {
    required String facetPrefix,
  }) {
    return _engine.getFacetCountsExact(
      query: request.query,
      facets: request.facets,
      facetPrefix: facetPrefix,
    );
  }

  @override
  Future<List<FacetCount>> getFacetCountsAdvanced(
    SearchEngineRequest request, {
    required String facetPrefix,
  }) {
    return _engine.getFacetCountsAdvanced(
      query: request.query,
      facets: request.facets,
      facetPrefix: facetPrefix,
      distance: request.distance,
      customSpacing: request.customSpacing,
      alternativeWords: request.alternativeWords,
      searchOptions: request.searchOptions,
    );
  }

  @override
  Future<List<FacetCount>> getFacetCountsFuzzy(
    SearchEngineRequest request, {
    required String facetPrefix,
  }) {
    return _engine.getFacetCountsFuzzy(
      query: request.query,
      facets: request.facets,
      facetPrefix: facetPrefix,
      maxDistance: _fuzzyDistance(request.distance),
    );
  }

  /// המימוש האמיתי של ה-stream המשולב: קריאה אחת למנוע, שמריצה את השאילתה
  /// פעם אחת ומחזירה ספירות + תוצאות מאותו מעבר אינדקס.
  @override
  Stream<SearchStreamUpdate> searchStreamWithCounts(
    SearchEngineRequest request, {
    required int chunkSize,
  }) {
    switch (request.searchMode) {
      case SearchMode.exact:
        return _engine.searchExactStreamWithCounts(
          query: request.query,
          facets: request.facets,
          limit: request.limit,
          offset: request.offset,
          order: request.order,
          chunkSize: chunkSize,
        );
      case SearchMode.advanced:
        return _engine.searchAdvancedStreamWithCounts(
          query: request.query,
          facets: request.facets,
          limit: request.limit,
          offset: request.offset,
          distance: request.distance,
          customSpacing: request.customSpacing,
          alternativeWords: request.alternativeWords,
          searchOptions: request.searchOptions,
          order: request.order,
          chunkSize: chunkSize,
        );
      case SearchMode.fuzzy:
        return _engine.searchFuzzyStreamWithCounts(
          query: request.query,
          facets: request.facets,
          limit: request.limit,
          offset: request.offset,
          maxDistance: _fuzzyDistance(request.distance),
          order: request.order,
          chunkSize: chunkSize,
        );
    }
  }

  static int _fuzzyDistance(int distance) {
    return distance.clamp(0, 2).toInt();
  }

  /// מזין מראש את תבנית ההדגשה מבוססת-האינדקס (ראה
  /// `text_manipulation.primeHighlightPattern`). מפתח המטמון נגזר מאותם
  /// פרמטרים ש-`utils.highLight` ישתמש בהם ברינדור, כך שהתבנית תימצא שם.
  ///
  /// במצב exact אין פער להשלים: החיפוש מתאים רק את הטוקנים המדויקים, ותבנית
  /// ה-fallback הסינכרונית כבר מדגישה בדיוק אותם.
  @override
  void primeHighlightPattern(SearchEngineRequest request) {
    if (request.query.trim().isEmpty ||
        request.searchMode == SearchMode.exact) {
      return;
    }
    unawaited(text_utils.primeHighlightPattern(
      searchQuery: request.query,
      searchOptions: request.searchOptions,
      alternativeWords: request.alternativeWords,
      spacingValues: request.customSpacing,
      searchDistance: request.distance,
      isFuzzy: request.searchMode == SearchMode.fuzzy,
      fetch: () => switch (request.searchMode) {
        SearchMode.advanced => _engine.generateIndexHighlightPattern(
            query: request.query,
            distance: request.distance < 0 ? 0 : request.distance,
            customSpacing: request.customSpacing,
            alternativeWords: request.alternativeWords,
            searchOptions: request.searchOptions,
          ),
        SearchMode.fuzzy => _engine.generateIndexFuzzyHighlightPattern(
            query: request.query,
            maxDistance: _fuzzyDistance(request.distance),
          ),
        SearchMode.exact => Future.value(null),
      },
    ));
  }
}

class SearchEngineGateway {
  const SearchEngineGateway();

  Future<List<SearchResult>> search(
    SearchEngineOperations engine,
    SearchEngineRequest request,
  ) async {
    // בזמן שהחיפוש רץ, תבנית ההדגשה לספר-פתוח נבנית ברקע מאותם פרמטרים —
    // עד שהמשתמש יפתח תוצאה היא כבר במטמון.
    engine.primeHighlightPattern(request);
    switch (request.searchMode) {
      case SearchMode.exact:
        return engine.searchExact(request);
      case SearchMode.advanced:
        return engine.searchAdvanced(request);
      case SearchMode.fuzzy:
        return engine.searchFuzzy(request);
    }
  }

  Future<SearchPageResult> searchAndCount(
    SearchEngineOperations engine,
    SearchEngineRequest request,
  ) async {
    engine.primeHighlightPattern(request);
    switch (request.searchMode) {
      case SearchMode.exact:
        return engine.searchAndCountExact(request);
      case SearchMode.advanced:
        return engine.searchAndCountAdvanced(request);
      case SearchMode.fuzzy:
        return engine.searchAndCountFuzzy(request);
    }
  }

  Stream<List<SearchResult>> searchStream(
    SearchEngineOperations engine,
    SearchEngineRequest request, {
    required int chunkSize,
  }) {
    engine.primeHighlightPattern(request);
    switch (request.searchMode) {
      case SearchMode.exact:
        return engine.searchExactStream(request, chunkSize: chunkSize);
      case SearchMode.advanced:
        return engine.searchAdvancedStream(request, chunkSize: chunkSize);
      case SearchMode.fuzzy:
        return engine.searchFuzzyStream(request, chunkSize: chunkSize);
    }
  }

  /// Stream משולב (תוצאות + ספירה כוללת + ספירה לפי ספר במעבר אחד);
  /// ראה [SearchEngineOperations.searchStreamWithCounts].
  Stream<SearchStreamUpdate> searchStreamWithCounts(
    SearchEngineOperations engine,
    SearchEngineRequest request, {
    required int chunkSize,
  }) {
    engine.primeHighlightPattern(request);
    return engine.searchStreamWithCounts(request, chunkSize: chunkSize);
  }

  Future<int> count(
    SearchEngineOperations engine,
    SearchEngineRequest request,
  ) async {
    switch (request.searchMode) {
      case SearchMode.exact:
        return engine.countExact(request);
      case SearchMode.advanced:
        return engine.countAdvanced(request);
      case SearchMode.fuzzy:
        return engine.countFuzzy(request);
    }
  }

  Future<Map<String, int>> countByBook(
    SearchEngineOperations engine,
    SearchEngineRequest request,
  ) async {
    switch (request.searchMode) {
      case SearchMode.exact:
        return engine.countByBookExact(request);
      case SearchMode.advanced:
        return engine.countByBookAdvanced(request);
      case SearchMode.fuzzy:
        return engine.countByBookFuzzy(request);
    }
  }

  Future<List<FacetCount>> getFacetCounts(
    SearchEngineOperations engine,
    SearchEngineRequest request, {
    required String facetPrefix,
  }) async {
    switch (request.searchMode) {
      case SearchMode.exact:
        return engine.getFacetCountsExact(
          request,
          facetPrefix: facetPrefix,
        );
      case SearchMode.advanced:
        return engine.getFacetCountsAdvanced(
          request,
          facetPrefix: facetPrefix,
        );
      case SearchMode.fuzzy:
        return engine.getFacetCountsFuzzy(
          request,
          facetPrefix: facetPrefix,
        );
    }
  }
}
