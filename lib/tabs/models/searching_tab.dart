import 'package:flutter/material.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:otzaria/models/books.dart';

class SearchingTab extends OpenedTab {
  final searchBloc = SearchBloc();
  final queryController = TextEditingController();
  final searchFieldFocusNode = FocusNode();
  final ValueNotifier<bool> isLeftPaneOpen = ValueNotifier(true);
  final ItemScrollController scrollController = ItemScrollController();
  List<Book> allBooks = [];

  // אפשרויות חיפוש לכל מילה (מילה_אינדקס -> אפשרויות)
  final Map<String, Map<String, bool>> searchOptions = {};

  // מילים חילופיות לכל מילה (אינדקס_מילה -> רשימת מילים חילופיות)
  final Map<int, List<String>> alternativeWords = {};

  // מרווחים בין מילים (מפתח_מרווח -> ערך_מרווח)
  final Map<String, String> spacingValues = {};

  // notifier לעדכון התצוגה כשמשתמש משנה אפשרויות
  final ValueNotifier<int> searchOptionsChanged = ValueNotifier(0);

  // notifier לעדכון התצוגה כשמשתמש משנה מילים חילופיות
  final ValueNotifier<int> alternativeWordsChanged = ValueNotifier(0);

  // notifier לעדכון התצוגה כשמשתמש משנה מרווחים
  final ValueNotifier<int> spacingValuesChanged = ValueNotifier(0);

  // מטמון של בקשות ספירה פעילות כדי למנוע קריאות כפולות
  final Map<String, Future<int>> _inflight = {};

  SearchingTab(
    super.title,
    String? searchText, {
    super.isPinned = false,
  }) {
    if (searchText != null) {
      queryController.text = searchText;
      searchBloc.add(UpdateSearchQuery(searchText.trim()));
    }
  }

  String _normalizeFacet(String s) =>
      s.trim().replaceAll(RegExp(r'/+'), '/'); // אחידות סלאשים + רווחים

  String _optionsHash() {
    String normMap(Map m) => Map.fromEntries(m.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString())))
        .toString();
    return [
      normMap(searchOptions),
      normMap(spacingValues),
      Map.fromEntries(alternativeWords.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .toString(),
    ].join('|');
  }

  String _cacheKey(String facet) {
    final f = _normalizeFacet(facet);
    final q = (searchBloc.state.searchQuery).trim();
    final bVer = searchBloc.state.booksToSearch.length.toString(); // מספר ספרים
    return '$f|q=$q|o=${_optionsHash()}|b=$bVer';
  }

  Future<int> countForFacet(String facet) {
    return searchBloc.countForFacet(
      facet,
      customSpacing: spacingValues,
      alternativeWords: alternativeWords,
      searchOptions: searchOptions,
    );
  }

  /// ספירה מקבצת של תוצאות עבור מספר facets בבת אחת - לשיפור ביצועים
  Future<Map<String, int>> countForMultipleFacets(List<String> facets) {
    return searchBloc.countForMultipleFacets(
      facets,
      customSpacing: spacingValues,
      alternativeWords: alternativeWords,
      searchOptions: searchOptions,
    );
  }

  /// ספירה חכמה - מחזירה תוצאות מהירות מה-state או מבצעת ספירה
  Future<int> countForFacetCached(String facet) async {
    final f = _normalizeFacet(facet);

    // 0) אם יש ב-state (כולל 0) — החזר מיד
    if (searchBloc.state.facetCounts.containsKey(f)) {
      final v = searchBloc.getFacetCountFromState(f);
      debugPrint('💾 Cache hit for $f: $v');
      return v;
    }

    // 1) מפתח קאש כולל query/אפשרויות/גרסת ספרים
    final key = _cacheKey(facet);

    // 2) אם ספירה פעילה — הצמד אליה
    final existing = _inflight[key];
    if (existing != null) {
      debugPrint('⏳ Count in progress for [$key], waiting...');
      return existing;
    }

    debugPrint('🔄 Cache miss for $key, direct count...');
    final sw = Stopwatch()..start();

    final fut = countForFacet(f).then((result) {
      sw.stop();
      debugPrint(
          '⏱️ Direct count for $key took ${sw.elapsedMilliseconds}ms: $result');
      searchBloc.add(UpdateFacetCounts({f: result}));
      return result;
    }).whenComplete(() {
      // תמיד מנקים, גם בשגיאה
      _inflight.remove(key);
    });

    _inflight[key] = fut;
    return fut;
  }

  /// מחזיר ספירה סינכרונית מה-state (אם קיימת)
  int getFacetCountFromState(String facet) {
    return searchBloc.getFacetCountFromState(_normalizeFacet(facet));
  }

  @override
  void dispose() {
    searchFieldFocusNode.dispose();
    searchOptionsChanged.dispose();
    alternativeWordsChanged.dispose();
    spacingValuesChanged.dispose();
    // סגירת ה-bloc כדי למנוע דליפה
    searchBloc.close();
    super.dispose();
  }

  factory SearchingTab.fromJson(Map<String, dynamic> json) {
    final tab = SearchingTab(json['title'], json['searchText'],
        isPinned: json['isPinned'] ?? false);
    return tab;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'searchText': queryController.text,
      'isPinned': isPinned,
      'type': 'SearchingTabWindow'
    };
  }
}
