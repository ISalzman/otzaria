import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/messages/plugin_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/plugins/declarative/services/declarative_library_book_access.dart';
import 'package:otzaria/plugins/services/plugin_external_search_service.dart';
import 'package:otzaria/plugins/services/plugin_in_book_search_service.dart';
import 'package:otzaria/plugins/services/plugin_search_dialog_registry.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_state.dart';
import 'package:otzaria/search/models/external_search_summary.dart';
import 'package:otzaria/search/utils/facet_helper.dart';
import 'package:otzaria/search/view/search_result_source_tag.dart';
import 'package:otzaria/search/utils/snippet_builder.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/models/external_book_matches.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/theme/app_tokens.dart';
import 'package:otzaria/utils/navigation/book_open_coordinator.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

/// מדור תוצאות ממקור חיצוני של תוסף (למשל היברובוקס) בטאב החיפוש המובנה.
///
/// המדור פעיל רק כשסומנה בדיאלוג החיפוש שורת תוסף שהצהירה `resultsProvider`
/// והתוסף נרשם כספק. השאילתה נשלחת לתוסף כאירוע ממוקד — אוצריא עצמה אינה
/// פונה לשירות החיפוש החיצוני. לחיצה על תוצאה פותחת את הספר במציג המובנה
/// (מקומית כשהקובץ קיים בתיקיית ההיברובוקס), עם עמודי ההתאמה כשהספק
/// חיפוש-בתוך-ספר זמין.
///
/// לצד עמודי התוצאות, הספק מצרף אינדקס תמציתי של כלל התוצאות עם קטגוריה
/// לכל ספר — הסיווג כולו (כולל עידון מול קטלוג השוואות, אם יש לספק כזה)
/// באחריות הספק; המדור רק מאמת את הנתיבים מול עץ הספרייה ומפרסם סיכום
/// ספירות דרך [SearchingTab.externalSearchSummary] — כך התוצאות החיצוניות
/// משתתפות בעץ הקטגוריות של החיפוש, ובחירת קטגוריה מסננת גם אותן (דפדוף
/// לפי ids).
class ExternalSearchResultsSection extends StatefulWidget {
  final SearchingTab tab;

  const ExternalSearchResultsSection({super.key, required this.tab});

  @override
  State<ExternalSearchResultsSection> createState() =>
      _ExternalSearchResultsSectionState();
}

/// נתיב הקטגוריה שמייצג facet שנבחר בעץ עבור סינון המדור: facet של ספר
/// (המקטע האחרון הוא מפתח ספר — 'id:'/'uid:'/'ext:'/נתיב קובץ, תמיד עם ':')
/// מתקפל לקטגוריית האם שלו.
@visibleForTesting
String externalFilterCategoryOf(String facet) {
  final segments = facet
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isNotEmpty && segments.last.contains(':')) {
    segments.removeLast();
  }
  return segments.isEmpty ? '/' : '/${segments.join('/')}';
}

/// אימות נתיב קטגוריה שהספק צירף לרשומת אינדקס מול עץ הספרייה: נתיב קיים
/// מתקבל כמות שהוא; אחרת נופלים לקטגוריית-העל שלו אם היא קיימת; אחרת null
/// (הספר יוצג בדלי "עוד מ<מקור>").
@visibleForTesting
String? externalValidatedCategoryOf(
  String? suggested,
  Set<String> validPaths,
) {
  if (suggested == null) return null;
  if (validPaths.contains(suggested)) return suggested;
  final segments = suggested.split('/').where((s) => s.isNotEmpty);
  if (segments.isEmpty) return null;
  final top = '/${segments.first}';
  return validPaths.contains(top) ? top : null;
}

/// המזהים מתוך [index] שסיווגם ([categories]) תואם את בחירת הקטגוריות
/// [facets] (OR ביניהן; קטגוריה תואמת גם את צאצאיה). [otherFacet] הוא דלי
/// "עוד מ<מקור>" — תואם תוצאות ללא סיווג.
@visibleForTesting
List<int> externalVisibleIdsFor({
  required List<ExternalSearchIndexEntry> index,
  required Map<int, String?> categories,
  required List<String> facets,
  required String? otherFacet,
}) {
  bool matches(String? path) {
    for (final facet in facets) {
      if (facet == '/') return true;
      if (facet == otherFacet) {
        if (path == null) return true;
        continue;
      }
      if (path != null && (path == facet || path.startsWith('$facet/'))) {
        return true;
      }
    }
    return false;
  }

  return [
    for (final entry in index)
      if (matches(categories[entry.id])) entry.id,
  ];
}

class _ExternalSearchResultsSectionState
    extends State<ExternalSearchResultsSection> {
  static const _pageSize = 20;
  static const _listMaxHeight = 420.0;
  static const _inBookMatchesTimeout = Duration(seconds: 15);

  final List<ExternalSearchResult> _results = [];
  int _totalBooks = 0;
  int _totalHits = 0;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  bool _expanded = true;
  Object? _openingId;

  /// חתימת הבקשה האחרונה — מזהה מתי צריך חיפוש חדש ומסנן תשובות ישנות.
  String _fetchSignature = '';

  /// בחירת הקטגוריות בעץ — שינוי בה מסנן את המדור מחדש בלי חיפוש חדש.
  /// המפתח מחבר ב-NUL כי נתיבי קטגוריות מכילים רווחים.
  List<String> _filterFacets = const [];
  String _filterKey = '';

  /// דור הבקשות: כל איפוס (חיפוש חדש / שינוי סינון) מקדם אותו, ותשובות
  /// של דור ישן — כולל כאלה שכבר היו בטיסה — נזרקות.
  int _fetchGeneration = 0;

  /// אינדקס כלל התוצאות מהספק, והסיווג הסופי (אחרי עידון ואימות) לכל מזהה.
  List<ExternalSearchIndexEntry>? _index;
  Map<int, String?>? _categoryById;
  ExternalSearchSummary? _summary;

  /// במצב מסונן: מזהי התוצאות התואמות את הקטגוריות שנבחרו, בסדר האינדקס,
  /// וכמה מהם כבר התבקשו (המזהים החסרים במטמון הספק אינם חוזרים כשורות,
  /// ולכן העמוד הבא נספר לפי מזהים שנצרכו — לא לפי שורות שהוצגו).
  List<int>? _visibleIds;
  int _visibleConsumed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncWithState(widget.tab.searchBloc.state);
    });
  }

  /// שם המקור לתגית שעל כל שורה — [resultsTitle] של שורת התוסף.
  String _sourceTag = '';

  /// שורת התוסף הפעילה: מסומנת בטאב, מצהירה resultsProvider והספק רשום.
  (String provider, String title)? _activeProvider(SearchState state) {
    final selections = state.configuration.pluginSearchSelections;
    for (final (pluginId, item)
        in PluginSearchDialogRegistry.instance.getAll()) {
      final provider = item.resultsProvider;
      if (provider == null) continue;
      if (selections['$pluginId/${item.id}'] != true) continue;
      if (!item.isVisibleIn(state.configuration.searchMode)) continue;
      if (!PluginExternalSearchService.instance.hasProvider(provider)) {
        continue;
      }
      return (provider, item.resultsTitle);
    }
    return null;
  }

  /// בחירת הקטגוריות הפעילה בעץ (בלי השורש ובלי ממדים) — הסינון של המדור.
  /// facet של ספר מתקפל לקטגוריית האם שלו.
  List<String> _selectedCategoryFacets(SearchState state) =>
      FacetHelper.categoryFacetsOf(state.currentFacets)
          .map(externalFilterCategoryOf)
          .where((facet) => facet != '/')
          .toSet()
          .toList()
        ..sort();

  void _syncWithState(SearchState state) {
    final active = _activeProvider(state);
    final query = state.searchQuery.trim();
    final signature = active == null || query.isEmpty
        ? ''
        : '${active.$1} $query '
              '${state.configuration.searchMode.name} ${state.distance}';
    final filterFacets = signature.isEmpty
        ? const <String>[]
        : _selectedCategoryFacets(state);
    // נתיבי קטגוריות מכילים רווחים — מפתח ההשוואה מחבר בתו שאינו חוקי בנתיב.
    final filterKey = filterFacets.join('\u0000');
    if (signature == _fetchSignature) {
      if (filterKey != _filterKey) {
        _filterFacets = filterFacets;
        _filterKey = filterKey;
        _applyFilterAndRefetch(state, active);
      }
      return;
    }
    _fetchSignature = signature;
    _filterFacets = filterFacets;
    _filterKey = filterKey;
    _fetchGeneration++;
    _index = null;
    _categoryById = null;
    _visibleIds = null;
    _visibleConsumed = 0;
    _summary = null;
    widget.tab.externalSearchSummary.value = null;
    setState(() {
      _results.clear();
      _totalBooks = 0;
      _totalHits = 0;
      _hasMore = false;
      _error = null;
      _loading = signature.isNotEmpty;
    });
    if (signature.isNotEmpty) {
      unawaited(_fetch(state, active!.$1, reset: true));
    }
  }

  /// מחשב מחדש את המזהים הנראים לפי הסינון ומביא את העמוד הראשון שלהם.
  /// סינון בלי אף תוצאה תואמת מציג "לא נמצאו תוצאות" בלי לפנות לספק.
  void _applyFilterAndRefetch(
    SearchState state,
    (String, String)? active,
  ) {
    if (active == null) return;
    _recomputeVisibleIds();
    _fetchGeneration++;
    _visibleConsumed = 0;
    final visible = _visibleIds;
    setState(() {
      _results.clear();
      _error = null;
      _hasMore = false;
      if (visible != null) {
        _totalBooks = visible.length;
        _totalHits = _hitsOf(visible);
      }
      _loading = visible == null || visible.isNotEmpty;
    });
    if (visible == null || visible.isNotEmpty) {
      unawaited(_fetch(state, active.$1, reset: true));
    }
  }

  /// הסינון פעיל רק כשנבחרו קטגוריות ויש סיווג מוכן.
  bool get _filterActive => _filterFacets.isNotEmpty && _visibleIds != null;

  void _recomputeVisibleIds() {
    final index = _index;
    final categories = _categoryById;
    if (_filterFacets.isEmpty || index == null || categories == null) {
      _visibleIds = null;
      return;
    }
    _visibleIds = externalVisibleIdsFor(
      index: index,
      categories: categories,
      facets: _filterFacets,
      otherFacet: _summary?.otherCategoryFacet,
    );
  }

  Future<void> _fetch(
    SearchState state,
    String provider, {
    required bool reset,
  }) async {
    final generation = _fetchGeneration;
    final signature = _fetchSignature;
    final offset = reset ? 0 : _results.length;
    final filtered = _filterActive;
    final visibleIds = _visibleIds;
    final idsOffset = reset ? 0 : _visibleConsumed;
    final idsSlice = filtered && visibleIds != null
        ? visibleIds.skip(idsOffset).take(_pageSize).toList()
        : null;
    // עדכון חלקי מחליף את חלון העמוד הנוכחי; הספירות הן רף-תחתון עד
    // לתשובה הסופית, וחיווי הטעינה נשאר דלוק.
    void applyPage(ExternalSearchPage page, {required bool done}) {
      if (!mounted || generation != _fetchGeneration) return;
      // אינדקס בלי סיווג מוכן (גם אחרי ניסיון שנכשל) — מסווגים (מחדש).
      if (page.index != null && _categoryById == null) {
        _index = page.index;
        _classifyIndex(signature);
      }
      setState(() {
        _results.removeRange(
          offset > _results.length ? _results.length : offset,
          _results.length,
        );
        _results.addAll(page.results);
        if (idsSlice != null) {
          // במצב מסונן הספירות מקומיות — הספק מחזיר את סיכומי החיפוש כולו.
          _totalBooks = visibleIds!.length;
          _totalHits = _hitsOf(visibleIds);
          if (done) _visibleConsumed = idsOffset + idsSlice.length;
          _hasMore = done && _visibleConsumed < visibleIds.length;
        } else {
          _totalBooks = page.totalBooks;
          _totalHits = page.totalHits;
          _hasMore = done && page.hasMore && page.results.isNotEmpty;
        }
        _loading = !done;
      });
    }

    try {
      final page = await PluginExternalSearchService.instance.search(
        provider: provider,
        query: state.searchQuery.trim(),
        mode: state.configuration.searchMode.name,
        distance: state.distance,
        offset: offset,
        limit: _pageSize,
        ids: idsSlice,
        onUpdate: (partial) => applyPage(partial, done: false),
      );
      applyPage(page, done: true);
    } catch (error) {
      if (!mounted || generation != _fetchGeneration) return;
      setState(() {
        _loading = false;
        _error = error is TimeoutException
            ? 'החיפוש החיצוני לא ענה בזמן'
            : error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  int _hitsOf(List<int> ids) {
    final index = _index;
    if (index == null) return 0;
    final idSet = ids.toSet();
    var total = 0;
    for (final entry in index) {
      if (idSet.contains(entry.id)) total += entry.hits;
    }
    return total;
  }

  /// מסווג את האינדקס: נתיבי הקטגוריות שהספק צירף (הסיווג עצמו נעשה בצד
  /// הספק — לאוצריא אין ידע ייחודי למקור) מאומתים מול עץ הספרייה, עם
  /// נפילה לקטגוריית-העל. התוצאה מתפרסמת לעץ הסינון של הטאב.
  void _classifyIndex(String signature) {
    final index = _index;
    if (index == null) return;
    final library = context.read<LibraryBloc>().state.library;
    final active = _activeProvider(widget.tab.searchBloc.state);
    if (library == null || active == null) {
      // אין עדיין ספרייה — משאירים את המדור בלי אינדקס כדי שהעותק שמגיע
      // עם התשובה הסופית ינסה לסווג שוב.
      _index = null;
      return;
    }
    if (signature != _fetchSignature) return;

    final validPaths = <String>{
      for (final category in library.getAllCategories()) category.path,
    };

    final categories = <int, String?>{};
    final counts = <String, int>{};
    var other = 0;
    for (final entry in index) {
      final path = externalValidatedCategoryOf(entry.categoryPath, validPaths);
      categories[entry.id] = path;
      if (path == null) {
        other += 1;
      } else {
        counts[path] = (counts[path] ?? 0) + 1;
      }
    }
    var totalHits = 0;
    for (final entry in index) {
      totalHits += entry.hits;
    }

    _categoryById = categories;
    _summary = ExternalSearchSummary(
      provider: active.$1,
      sourceTitle: active.$2,
      totalBooks: index.length,
      totalHits: totalHits,
      categoryBookCounts: counts,
      otherBooks: other,
    );
    widget.tab.externalSearchSummary.value = _summary;

    // סינון שהמתין לסיווג (קטגוריה נבחרה לפני שהאינדקס הגיע) נכנס עכשיו.
    if (_filterKey.isNotEmpty) {
      _applyFilterAndRefetch(widget.tab.searchBloc.state, active);
    }
  }

  void _loadMore(SearchState state) {
    final active = _activeProvider(state);
    if (active == null || _loading) return;
    setState(() => _loading = true);
    unawaited(_fetch(state, active.$1, reset: false));
  }

  Future<void> _openResult(
    ExternalSearchResult result,
    SearchState state,
  ) async {
    if (_openingId != null) return;
    setState(() => _openingId = result.externalId);
    final query = state.searchQuery.trim();
    // לוכדים את התלויות לפני נקודות ה-await — ה-context עלול להתפרק בינתיים.
    final access = DeclarativeLibraryBookAccess.otzaria(
      BookOpenCoordinator(
        tabsBloc: context.read<TabsBloc>(),
        historyBloc: context.read<HistoryBloc>(),
        navigationBloc: context.read<NavigationBloc>(),
      ),
    );
    try {
      // עמודי ההתאמה מגיעים מספק החיפוש-בתוך-ספר של התוסף; כישלון או
      // איטיות אינם מונעים את פתיחת הספר — פותחים בלעדיהם.
      ExternalBookMatches? matches;
      if (PluginInBookSearchService.instance.hasProvider(result.provider)) {
        try {
          matches = await PluginInBookSearchService.instance
              .search(
                provider: result.provider,
                externalId: result.externalId,
                query: query,
              )
              .timeout(_inBookMatchesTimeout);
        } catch (_) {
          matches = null;
        }
      }
      final opened = await access.openUnique(
        {
          'external': {'provider': result.provider, 'id': result.externalId},
        },
        index: result.firstPage ?? 1,
        searchQuery: query,
        externalMatches: matches,
      );
      if (!opened) {
        UiSnack.show(PluginMessages.externalBookNotFound);
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SearchBloc, SearchState>(
      bloc: widget.tab.searchBloc,
      listener: (context, state) => _syncWithState(state),
      builder: (context, state) {
        final active = _activeProvider(state);
        if (active == null || state.searchQuery.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        _sourceTag = active.$2;
        return _buildSection(context, state, active.$2);
      },
    );
  }

  Widget _buildSection(BuildContext context, SearchState state, String title) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, title),
          if (_expanded) _buildBody(context, state),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    final filteredNote = _filterActive && _summary != null
        ? ' (מתוך ${_summary!.totalBooks})'
        : '';
    final summary = _totalBooks > 0
        ? '$title — $_totalBooks ספרים$filteredNote, $_totalHits מופעים'
        : title;
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: cs.secondaryContainer,
        child: Row(
          children: [
            Icon(FluentIcons.globe_search_24_regular, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: 8),
            Icon(
              _expanded
                  ? FluentIcons.chevron_up_24_regular
                  : FluentIcons.chevron_down_24_regular,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            ActionButton.ghost(
              text: 'נסה שוב',
              onPressed: () {
                _fetchSignature = '';
                _syncWithState(state);
              },
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_loading ? 'מחפש…' : 'לא נמצאו תוצאות'),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _listMaxHeight),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: _results.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _results.length) {
            return Center(
              child: ActionButton.ghost(
                onPressed: _loading ? null : () => _loadMore(state),
                text: _loading
                    ? 'טוען…'
                    : 'טען תוצאות נוספות (${_totalBooks - _results.length})',
              ),
            );
          }
          return BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settings) =>
                _buildResultRow(context, state, _results[index], settings),
          );
        },
      ),
    );
  }

  /// כרטיס תוצאה באותה שפה עיצובית של תוצאות הספרייה במסך הזה: מסגרת
  /// מעוגלת, ריווח פנימי נדיב ושורת קטע בגובה קריא — ולא ListTile צפוף.
  ///
  /// גזיר הטקסט נצבע בגופן הספרים של המשתמש ([SettingsState.fontFamily]
  /// ובגודלו), כמו גזירי המנוע המובנה — אחרת אותה שאילתה מוצגת בשני גופנים
  /// שונים באותו מסך.
  Widget _buildResultRow(
    BuildContext context,
    SearchState state,
    ExternalSearchResult result,
    SettingsState settings,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final opening = _openingId == result.externalId;
    final enabled = _openingId == null || opening;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        borderRadius: AppTokens.borderRadiusAll,
      ),
      child: InkWell(
        onTap: enabled ? () => unawaited(_openResult(result, state)) : null,
        borderRadius: AppTokens.borderRadiusAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              opening
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      FluentIcons.book_open_24_regular,
                      size: 20,
                      color: cs.primary,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            result.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (result.hitCount > 0) ...[
                          const SizedBox(width: 8),
                          _buildHitCountPill(context, result.hitCount),
                        ],
                        const Spacer(),
                        // תגית מקור בקצה השורה, באותו מקום שבו היא מופיעה
                        // על תוצאות המנוע המובנה.
                        if (_sourceTag.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          SearchResultSourceTag(label: _sourceTag),
                        ],
                        if (result.snippet != null) ...[
                          const SizedBox(width: 4),
                          _buildCopyButton(context, result.snippet!),
                        ],
                      ],
                    ),
                    // result.meta (מחבר · מקום · שנה) אינו מוצג: כרטיס תוצאה
                    // של המנוע המובנה אינו נושא פרטי ספר, והשורה הזו רק
                    // הרחיקה את הגזיר מהכותרת.
                    if (result.snippet != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: RichText(
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.justify,
                          text: TextSpan(
                            children: SnippetBuilder.highlightLiteral(
                              plainText: result.snippet!,
                              query: state.searchQuery.trim(),
                              defaultStyle: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                                color: cs.onSurface,
                                height: 1.5,
                              ),
                              highlightStyle: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily,
                                height: 1.5,
                                fontWeight: FontWeight.bold,
                                backgroundColor: cs.primaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// מספר המופעים בספר, לצד שמו: מספר עירום בקצה הכרטיס לא אמר מה הוא סופר.
  Widget _buildHitCountPill(BuildContext context, int hitCount) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        hitCount == 1 ? 'תוצאה אחת בספר' : '$hitCount תוצאות בספר',
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSecondaryContainer,
        ),
      ),
    );
  }

  /// העתקת גזיר הטקסט, כמו בכרטיס תוצאה של המנוע המובנה — הגזיר כבר בידינו,
  /// ואין סיבה שדווקא כאן יידרש לפתוח את הספר כדי להעתיק ממנו.
  Widget _buildCopyButton(BuildContext context, String snippet) {
    return IconButton(
      icon: Icon(
        FluentIcons.copy_24_regular,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      tooltip: 'העתק טקסט',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () {
        Clipboard.setData(ClipboardData(text: snippet));
        UiSnack.show(UiSnack.textCopied);
      },
    );
  }
}
