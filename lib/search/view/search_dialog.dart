import 'package:flutter/material.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:otzaria/theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/history/bloc/history_state.dart';
import 'package:otzaria/search/search_scope_preferences.dart';
import 'package:otzaria/search/view/category_tree_selector.dart';
import 'package:otzaria/indexing/bloc/indexing_bloc.dart';
import 'package:otzaria/indexing/bloc/indexing_state.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_state.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/search_defaults.dart';
import 'package:otzaria/search/search_query_builder.dart';
import 'package:otzaria/search/saved_alternatives_store.dart';
import 'package:otzaria/search/utils/category_query_parser.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/search/view/enhanced_search_field.dart';
import 'package:otzaria/search/view/advanced_search_controls.dart';
import 'package:otzaria/search/view/full_text_settings_widgets.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/widgets/feedback/indexing_warning.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/utils/text/text_manipulation.dart' as utils;
import 'package:otzaria/tour/tour_target_keys.dart';

class SearchDialogResult {
  const SearchDialogResult({
    required this.query,
    required this.searchOptions,
    required this.alternativeWords,
    required this.spacingValues,
    required this.searchMode,
    required this.distance,
  });

  final String query;
  final Map<String, Map<String, bool>> searchOptions;
  final Map<int, List<String>> alternativeWords;
  final Map<String, String> spacingValues;
  final SearchMode searchMode;
  final int distance;
}

/// דיאלוג חיפוש מתקדם - מכיל את כל פקדי החיפוש וההגדרות
/// כשמבצעים חיפוש, הדיאלוג נסגר ונפתחת לשונית תוצאות
class SearchDialog extends StatefulWidget {
  final SearchingTab? existingTab;

  /// טאב תוצאות חי לעריכה: הדיאלוג נפתח עם כל הפרמטרים שלו, ובאישור
  /// החיפוש מוחל עליו במקום (ללא יצירת טאב חדש).
  final SearchingTab? editTab;
  final Function(
    String query,
    Map<String, Map<String, bool>> searchOptions,
    Map<int, List<String>> alternativeWords,
    Map<String, String> spacingValues,
    SearchMode searchMode,
    int distance,
  )? onSearch;
  final String? bookTitle;
  final bool returnResultOnSubmit;

  const SearchDialog(
      {super.key,
      this.existingTab,
      this.editTab,
      this.onSearch,
      this.bookTitle,
      this.returnResultOnSubmit = false});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  late SearchingTab _searchTab;
  FocusRestorer? _focusRestorer;
  bool _showIndexInProgressWarning = false;
  bool _showHistoryDropdown = false;
  bool _searchAllCategories = true;
  Set<String> _manualFacets = {};
  final ValueNotifier<bool> _advancedControlsHasFocus = ValueNotifier(false);
  late final VoidCallback _queryListener;
  Set<String> _selectedCategoryFacets = {'/'}; // ברירת מחדל: הכל
  late final bool _ownsSearchTab;
  // groupId משותף לכפתור ההיסטוריה ולמגירת ההיסטוריה — מאפשר ל-TapRegion
  // לזהות לחיצה על הכפתור עצמו כ"בתוך" האזור (כדי שלא תיגרם סגירה+פתיחה מיידית).
  final Object _historyTapRegionGroupId = Object();

  bool get _usesStagedSubmit =>
      widget.onSearch != null ||
      widget.returnResultOnSubmit ||
      widget.editTab != null;

  @override
  void initState() {
    super.initState();

    // יצירת טאב עם ההקלדה האחרונה
    _ownsSearchTab = widget.existingTab == null;
    if (widget.existingTab != null) {
      _searchTab = widget.existingTab!;
    } else if (widget.editTab != null) {
      // עריכה: עובדים על עותק — הטאב החי מתעדכן רק באישור החיפוש
      _searchTab = SearchingTab.clone(widget.editTab!);
    } else {
      final lastTyping =
          Settings.getValue<String>('key-last-search-typing') ?? '';
      final lastMode =
          Settings.getValue<String>('key-last-search-mode') ?? 'advanced';

      final searchMode = switch (lastMode) {
        'fuzzy' => SearchMode.fuzzy,
        'exact' => SearchMode.exact,
        _ => SearchMode.advanced,
      };

      _searchTab = SearchingTab(
        "חיפוש",
        lastTyping,
        initialConfiguration: SearchConfiguration(
          searchMode: searchMode,
          distance: searchMode == SearchMode.fuzzy ? 2 : 0,
        ),
      );

      // חיפוש חדש נפתח עם אפשרויות ברירת המחדל (או מצב הסשן הנוכחי)
      _searchTab.globalSearchOptions
          .addAll(SearchDefaults.initialOptionsForNewSearch());
    }

    final persisted = SearchScopePreferences.load();
    final initialScopeFacets = _searchTab.searchBloc.state.searchScopeFacets;

    if (initialScopeFacets.isNotEmpty) {
      // הטאב מגדיר scope מפורש — כבד אותו תמיד
      final isExplicitAll = initialScopeFacets.contains('/');
      _searchAllCategories = isExplicitAll;
      _manualFacets = isExplicitAll
          ? Set<String>.from(persisted.manualFacets)
          : Set<String>.from(initialScopeFacets);
    } else {
      _searchAllCategories = persisted.searchAllCategories;
      _manualFacets = Set<String>.from(persisted.manualFacets);
    }
    _selectedCategoryFacets =
        _searchAllCategories ? {'/'} : Set<String>.from(_manualFacets);

    // בדיקה אם האינדקס בתהליך בנייה - האזהרה ניתנת לסגירה ואינה חוסמת חיפוש
    final indexingState = context.read<IndexingBloc>().state;
    _showIndexInProgressWarning = indexingState is IndexingInProgress;

    // מאזין לשינויים בתיבת החיפוש כדי לעדכן את האפשרויות ולשמור את ההקלדה
    _queryListener = () {
      if (!mounted) return;
      // שמירת ההקלדה הנוכחית (לא בעריכה — כדי לא לדרוס את ההקלדה האחרונה)
      if (widget.editTab != null) return;
      Settings.setValue<String>(
        'key-last-search-typing',
        _searchTab.queryController.text,
      );
    };
    _searchTab.queryController.addListener(_queryListener);

    // בקשת פוקוס לתיבת החיפוש + רישום כ-active restorer לשחזור לאחר אירועי חלון
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchTab.searchFieldFocusNode.requestFocus();
        _focusRestorer = FocusRepository().registerActiveRestorer(
          restore: () {
            if (mounted) _searchTab.searchFieldFocusNode.requestFocus();
          },
          canRestore: () =>
              mounted &&
              _searchTab.searchFieldFocusNode.canRequestFocus &&
              (ModalRoute.of(context)?.isCurrent ?? false),
        );
      }
    });
  }

  Widget _buildIndexWarning() {
    return IndexingWarningContainer(
      inProgressDismissed: !_showIndexInProgressWarning,
      onDismiss: () => setState(() => _showIndexInProgressWarning = false),
    );
  }

  // בניית מגירת ההיסטוריה - מציג רק חיפושים מההיסטוריה הכללית
  Widget _buildHistoryDropdown() {
    return BlocBuilder<HistoryBloc, HistoryState>(
      builder: (context, state) {
        // סינון רק חיפושים
        final searchHistory =
            state.history.where((item) => item.isSearch).toList();

        if (searchHistory.isEmpty) return const SizedBox.shrink();

        // הגבלה ל-5 אחרונים
        final recentSearches = searchHistory.take(5).toList();

        return Container(
          margin: const EdgeInsets.only(top: 4),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: AppTokens.borderRadiusAll,
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ScrollConfiguration(
              behavior:
                  ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: recentSearches.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
                itemBuilder: (context, index) {
                  final bookmark = recentSearches[index];
                  final query = bookmark.book.title; // הטקסט הפשוט של החיפוש
                  final displayText =
                      bookmark.ref; // הטקסט המעוצב (עם קידומות וסיומות)
                  final originalIndex = state.history.indexOf(bookmark);

                  return ListTile(
                    dense: true,
                    leading:
                        const Icon(FluentIcons.search_24_regular, size: 18),
                    title: Text(
                      displayText,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: const Icon(FluentIcons.delete_24_regular, size: 18),
                      tooltip: 'מחק מההיסטוריה',
                      onPressed: () {
                        context
                            .read<HistoryBloc>()
                            .add(RemoveHistory(originalIndex));
                      },
                    ),
                    onTap: () {
                      // שחזור הטקסט הפשוט (ללא קידומות וסיומות)
                      _searchTab.queryController.text = query;

                      // שחזור האפשרויות הנוספות
                      // ההיסטוריה שומרת אפשרויות מורחבות פר-מילה,
                      // לכן מנקים את האפשרויות הגלובליות הקיימות ועוברים למצב פר-מילה
                      // כדי שלא יישארו הגדרות חבויות שיופיעו במעבר חזרה למצב גלובלי
                      if (bookmark.searchOptions != null) {
                        _searchTab.searchOptions.clear();
                        _searchTab.searchOptions
                            .addAll(bookmark.searchOptions!);
                        _searchTab.globalSearchOptions.clear();
                        _searchTab.useGlobalSearchOptions.value = false;
                      }
                      if (bookmark.alternativeWords != null) {
                        _searchTab.alternativeWords.clear();
                        _searchTab.alternativeWords
                            .addAll(bookmark.alternativeWords!);
                      }
                      if (bookmark.spacingValues != null) {
                        _searchTab.spacingValues.clear();
                        _searchTab.spacingValues
                            .addAll(bookmark.spacingValues!);
                      }

                      // עדכון התצוגה
                      setState(() {
                        _showHistoryDropdown = false;
                      });

                      _searchTab.searchFieldFocusNode.requestFocus();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    final restorer = _focusRestorer;
    if (restorer != null) FocusRepository().unregisterActiveRestorer(restorer);
    _searchTab.queryController.removeListener(_queryListener);
    _advancedControlsHasFocus.dispose();
    if (_ownsSearchTab) {
      if (widget.editTab == null) {
        // מצב האפשרויות נשמר לסשן הנוכחי; בהפעלה הבאה חוזרים לברירת המחדל
        SearchDefaults.rememberSessionOptions(_searchTab.globalSearchOptions);
      }
      _searchTab.dispose();
    }
    super.dispose();
  }

  void _performSearch() {
    // חסימת חיפוש כשאין אינדקס - חיפוש שמשתמש באינדקס לא יכול לרוץ.
    // אם ה-provider עוד לא הסתיים לטעון, לא חוסמים (השאילתה תמתין ל-engine).
    if (isSearchBlockedByMissingIndex(
      providerInitialized: TantivyDataProvider.instance.isInitialized.value,
    )) {
      UiSnack.showError('אינדקס לא קיים, לא ניתן לבצע חיפוש זה ללא אינדקס.');
      return;
    }

    String query = _searchTab.queryController.text.trim();

    if (query.isEmpty) {
      UiSnack.show('נא להזין טקסט לחיפוש');
      return;
    }

    // תחביר קטגוריה: `מונח@קטגוריה` מצמצם את החיפוש לקטגוריה לפי שם.
    final parsedCategory = parseCategoryQuery(
      query,
      context.read<LibraryBloc>().state.library,
    );
    if (parsedCategory.hasCategoryToken && !parsedCategory.categoryFound) {
      UiSnack.showError(
          'הקטגוריה או הספר "${parsedCategory.notFoundNames.join('", "')}" לא נמצאו');
      return;
    }
    query = parsedCategory.query;
    if (query.isEmpty) {
      UiSnack.show('נא להזין טקסט לחיפוש');
      return;
    }

    // החיפוש עובד תמיד על טקסט ללא ניקוד.
    if (utils.hasNikud(query)) {
      query = utils.removeVolwels(query);
    }
    query = SearchQueryBuilder.sanitizeQuery(query);

    // שמירת מצב החיפוש האחרון
    final currentState = _searchTab.searchBloc.state;
    final currentMode = currentState.configuration.searchMode;
    final effectiveOptions = SearchQueryBuilder.effectiveSearchOptions(
      query: query,
      useGlobalOptions: _searchTab.useGlobalSearchOptions.value,
      globalOptions: _searchTab.globalSearchOptions,
      perWordOptions: _searchTab.searchOptions,
    );
    // כשמתג "חלופות שמורות" דלוק — הרחבת החיפוש בחלופות הגלובליות השמורות
    final effectiveAlternatives = _searchTab.useSavedAlternatives
        ? SavedAlternativesStore.mergeIntoQuery(
            query, _searchTab.alternativeWords)
        : _searchTab.alternativeWords;
    final normalizedParameters = SearchQueryBuilder.normalizeParametersForMode(
      currentMode,
      customSpacing: _searchTab.spacingValues,
      alternativeWords: effectiveAlternatives,
      searchOptions: effectiveOptions,
    );
    final modeString = switch (currentMode) {
      SearchMode.advanced => 'advanced',
      SearchMode.exact => 'exact',
      SearchMode.fuzzy => 'fuzzy',
    };
    if (widget.editTab == null) {
      Settings.setValue<String>('key-last-search-mode', modeString);
    }

    if (widget.returnResultOnSubmit) {
      Navigator.of(context).pop(
        SearchDialogResult(
          query: query,
          searchOptions: normalizedParameters.searchOptions,
          alternativeWords: normalizedParameters.alternativeWords,
          spacingValues: normalizedParameters.customSpacing,
          searchMode: currentMode,
          distance: _searchTab.searchBloc.state.distance,
        ),
      );
      return;
    }

    if (widget.onSearch != null) {
      final onSearch = widget.onSearch!;
      final searchOptions = normalizedParameters.searchOptions;
      final alternativeWords = normalizedParameters.alternativeWords;
      final spacingValues = normalizedParameters.customSpacing;
      final distance = _searchTab.searchBloc.state.distance;

      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSearch(
          query,
          searchOptions,
          alternativeWords,
          spacingValues,
          currentMode,
          distance,
        );
      });
      return;
    }

    // ה-facets שנבחרו לחיפוש. תחביר `@קטגוריה`/`@ספר` גובר על הבחירה הידנית.
    final facetsToSearch = parsedCategory.categoryFound
        ? parsedCategory.facets!
        : _selectedCategoryFacets.isEmpty
            ? ['/']
            : _selectedCategoryFacets.toList();
    final distance = _searchTab.searchBloc.state.distance;

    if (widget.editTab != null) {
      _applyEditToTarget(
        query: query,
        mode: currentMode,
        distance: distance,
        facetsToSearch: facetsToSearch,
        effectiveAlternatives: effectiveAlternatives,
        normalizedParameters: normalizedParameters,
      );
      return;
    }

    // יצירת טאב חדש לגמרי - ללא קשר לטאב קודם.
    // ה-configuration מוזרקת בבנייה ולא דרך events אחרי AddTab, אחרת
    // snapshot השמירה של הטאבים מצלם את ברירת המחדל והמצב אובד בהפעלה הבאה.
    final newSearchTab = SearchingTab(
      "חיפוש: $query",
      query,
      initialConfiguration: SearchConfiguration(
        searchMode: currentMode,
        distance: distance,
        currentFacets: facetsToSearch,
        searchScopeFacets: facetsToSearch,
      ),
    );

    // העתקת כל ההגדרות מהטאב הנוכחי לטאב החדש
    newSearchTab.searchOptions.addAll(_searchTab.searchOptions.map(
      (key, value) => MapEntry(key, Map<String, bool>.from(value)),
    ));
    newSearchTab.globalSearchOptions.addAll(_searchTab.globalSearchOptions);
    newSearchTab.useGlobalSearchOptions.value =
        _searchTab.useGlobalSearchOptions.value;
    // חלופות שמורות שמוזגו הופכות לחלק מהטאב — נשמרות ומשוחזרות איתו
    newSearchTab.alternativeWords.addAll(effectiveAlternatives.map(
      (key, value) => MapEntry(key, List<String>.from(value)),
    ));
    newSearchTab.spacingValues.addAll(_searchTab.spacingValues);

    // מעבירים את ה-scope במפורש להיסטוריה — SetFacetsWithoutSearch מעדכן את
    // state אסינכרונית, ובלי זה החיפוש היה נשמר בלי ה-scope שנבחר.
    context
        .read<HistoryBloc>()
        .add(AddHistory(newSearchTab, scopeFacets: facetsToSearch));

    // ביצוע החיפוש בטאב החדש
    newSearchTab.searchBloc.add(
      UpdateSearchQuery(
        query,
        customSpacing: normalizedParameters.customSpacing,
        alternativeWords: normalizedParameters.alternativeWords,
        searchOptions: normalizedParameters.searchOptions,
      ),
    );

    // סגירת הדיאלוג
    Navigator.of(context).pop();

    // פתיחת טאב חדש תמיד
    final tabsBloc = context.read<TabsBloc>();
    final navigationBloc = context.read<NavigationBloc>();

    tabsBloc.add(AddTab(newSearchTab));

    // מעבר למסך העיון
    navigationBloc.add(const NavigateToScreen(Screen.search));
  }

  /// מחיל את פרמטרי הדיאלוג על טאב התוצאות הנערך ומריץ בו את החיפוש מחדש.
  void _applyEditToTarget({
    required String query,
    required SearchMode mode,
    required int distance,
    required List<String> facetsToSearch,
    required Map<int, List<String>> effectiveAlternatives,
    required SearchModeScopedParameters normalizedParameters,
  }) {
    final target = widget.editTab!;

    target.queryController.text = query;
    target.searchOptions
      ..clear()
      ..addAll(_searchTab.searchOptions.map(
        (key, value) => MapEntry(key, Map<String, bool>.from(value)),
      ));
    target.globalSearchOptions
      ..clear()
      ..addAll(_searchTab.globalSearchOptions);
    target.useGlobalSearchOptions.value =
        _searchTab.useGlobalSearchOptions.value;
    target.alternativeWords
      ..clear()
      ..addAll(effectiveAlternatives.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ));
    target.spacingValues
      ..clear()
      ..addAll(_searchTab.spacingValues);
    target.updateTitleFromAppliedQuery(query);

    target.searchBloc.add(SetSearchModeWithoutSearch(mode));
    target.searchBloc.add(UpdateDistanceWithoutSearch(distance));
    target.searchBloc.add(SetFacetsWithoutSearch(facetsToSearch));
    context
        .read<HistoryBloc>()
        .add(AddHistory(target, scopeFacets: facetsToSearch));
    target.searchBloc.add(UpdateSearchQuery(
      query,
      customSpacing: normalizedParameters.customSpacing,
      alternativeWords: normalizedParameters.alternativeWords,
      searchOptions: normalizedParameters.searchOptions,
    ));

    final tabsBloc = context.read<TabsBloc>();
    Navigator.of(context).pop();
    // שמירת הטאבים אחרי שאירועי ה-configuration הסינכרוניים עובדו,
    // אחרת ה-snapshot היה מצלם את המצב הישן של הטאב הנערך.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tabsBloc.add(const SaveTabs());
    });
  }

  void _setSearchAllCategories(bool value) {
    setState(() {
      _searchAllCategories = value;
      _selectedCategoryFacets =
          _searchAllCategories ? {'/'} : Set<String>.from(_manualFacets);
    });
    SearchScopePreferences.save(
      searchAllCategories: _searchAllCategories,
      manualFacets: _manualFacets,
    );
  }

  void _onManualFacetsChanged(Set<String> selection) {
    setState(() {
      _manualFacets = Set<String>.from(selection);
      if (!_searchAllCategories) {
        _selectedCategoryFacets = Set<String>.from(_manualFacets);
      }
    });
    SearchScopePreferences.save(
      searchAllCategories: _searchAllCategories,
      manualFacets: _manualFacets,
    );
  }

  Widget _buildCategoriesToggle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSpecific = !_searchAllCategories;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppSurfaces.togglePill(colorScheme, active: isSpecific),
        borderRadius: AppTokens.borderRadiusAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'כל הקטגוריות',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isSpecific
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: _searchAllCategories,
              onChanged: _setSearchAllCategories,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    IconData icon,
    SearchMode mode,
    bool isSelected,
  ) {
    return Tooltip(
      message: mode.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.read<SearchBloc>().add(
                  !_usesStagedSubmit
                      ? SetSearchMode(mode)
                      : SetSearchModeWithoutSearch(mode),
                );
            _searchTab.searchFieldFocusNode.requestFocus();
          },
          borderRadius: AppTokens.borderRadiusAll,
          child: Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Colors.transparent,
              borderRadius: AppTokens.borderRadiusAll,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  mode.shortLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.7).clamp(500.0, 900.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(450.0, 700.0);

    return BlocProvider.value(
      value: _searchTab.searchBloc,
      child: Dialog(
        child: FocusScope(
          onKeyEvent: (node, event) {
            // תפיסת Enter ברמת הדיאלוג - FocusScope תופס אירועים מכל הילדים
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              // אם הפוקוס בתוך אפשרויות מתקדמות - תן לשדה לטפל
              if (_advancedControlsHasFocus.value) {
                return KeyEventResult.ignored;
              }
              _performSearch();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            key: tourSearchDialogTargetKey,
            width: dialogWidth,
            height: dialogHeight,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // כותרת
                Row(
                  children: [
                    const Icon(FluentIcons.search_24_filled, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      widget.editTab != null
                          ? 'עריכת חיפוש'
                          : widget.bookTitle != null
                              ? 'חיפוש ב${widget.bookTitle}'
                              : 'חיפוש',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(FluentIcons.dismiss_24_regular),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'סגור',
                    ),
                  ],
                ),
                const Divider(height: 24),

                // אזהרת אינדקס
                _buildIndexWarning(),

                // תוכן הדיאלוג - Row עם ניווט מימין ותוכן משמאל
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Navigation Bar אנכי מימין
                      BlocBuilder<SearchBloc, SearchState>(
                        builder: (context, state) {
                          return Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildNavButton(
                                  context,
                                  FluentIcons.text_quote_24_regular,
                                  SearchMode.exact,
                                  state.configuration.searchMode ==
                                      SearchMode.exact,
                                ),
                                const SizedBox(height: 4),
                                _buildNavButton(
                                  context,
                                  FluentIcons.search_info_24_regular,
                                  SearchMode.advanced,
                                  state.configuration.searchMode ==
                                      SearchMode.advanced,
                                ),
                                const SizedBox(height: 4),
                                _buildNavButton(
                                  context,
                                  FluentIcons
                                      .arrow_bidirectional_left_right_24_regular,
                                  SearchMode.fuzzy,
                                  state.configuration.searchMode ==
                                      SearchMode.fuzzy,
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 16),

                      // תוכן ראשי
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // שדה החיפוש + מרווח בין מילים + כפתור קטגוריות
                            BlocBuilder<SearchBloc, SearchState>(
                              builder: (context, state) {
                                final searchField = Stack(
                                  children: [
                                    BlocProvider.value(
                                      value: _searchTab.searchBloc,
                                      child: EnhancedSearchField(
                                        key: enhancedSearchFieldKey,
                                        widget: _SearchDialogWrapper(
                                          tab: _searchTab,
                                        ),
                                        showInlineSearchButton: false,
                                        onSubmit: _performSearch,
                                        trailingAction: TapRegion(
                                          groupId: _historyTapRegionGroupId,
                                          child: IconButton(
                                            icon: Icon(
                                              _showHistoryDropdown
                                                  ? FluentIcons
                                                      .chevron_up_24_regular
                                                  : FluentIcons
                                                      .history_24_regular,
                                              size: 24,
                                            ),
                                            tooltip: 'היסטוריית חיפושים',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              setState(() {
                                                _showHistoryDropdown =
                                                    !_showHistoryDropdown;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    // כפתור חיפוש
                                    Positioned(
                                      right: 10,
                                      top: 8,
                                      bottom: 8,
                                      child: Center(
                                        child: ValueListenableBuilder<bool>(
                                          valueListenable: TantivyDataProvider
                                              .instance.isInitialized,
                                          builder: (context,
                                              providerInitialized, _) {
                                            final blocked =
                                                isSearchBlockedByMissingIndex(
                                              providerInitialized:
                                                  providerInitialized,
                                            );
                                            return IconButton(
                                              icon: const Icon(
                                                FluentIcons.search_24_filled,
                                                size: 20,
                                              ),
                                              tooltip: blocked
                                                  ? 'אינדקס לא קיים, לא ניתן לבצע חיפוש זה ללא אינדקס'
                                                  : 'חפש',
                                              onPressed: blocked
                                                  ? null
                                                  : _performSearch,
                                              style: IconButton.styleFrom(
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primaryContainer,
                                                foregroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer,
                                                padding:
                                                    const EdgeInsets.all(6),
                                                minimumSize: const Size(32, 32),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                );

                                final fuzzyDistanceWidget = Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: FuzzyDistance(
                                    tab: _searchTab,
                                    inputFocusNotifier:
                                        _advancedControlsHasFocus,
                                    triggerSearch: !_usesStagedSubmit,
                                  ),
                                );

                                final showCategoriesToggleWidget =
                                    widget.bookTitle == null;
                                final categoriesToggleWidget = Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: _buildCategoriesToggle(context),
                                );

                                // ב-LayoutBuilder: אם הרוחב צר — accessories לשורה שנייה
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    const distanceWidgetWidth = 152.0;
                                    const categoriesWidgetWidth = 138.0;
                                    final accessoriesWidth =
                                        distanceWidgetWidth +
                                            (showCategoriesToggleWidget
                                                ? categoriesWidgetWidth
                                                : 0);
                                    final hasAccessories = true;
                                    // FuzzyDistance=140px, toggle~130px, paddings~20px ≈ 290px
                                    final isNarrow = hasAccessories &&
                                        constraints.maxWidth <
                                            accessoriesWidth + 180;

                                    if (isNarrow) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          searchField,
                                          const SizedBox(height: 8),
                                          Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            runSpacing: 8,
                                            children: [
                                              fuzzyDistanceWidget,
                                              if (showCategoriesToggleWidget)
                                                categoriesToggleWidget,
                                            ],
                                          ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(child: searchField),
                                        fuzzyDistanceWidget,
                                        if (showCategoriesToggleWidget)
                                          categoriesToggleWidget,
                                      ],
                                    );
                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // תוכן תחתון - אפשרויות מתקדמות + חלונית קטגוריות.
                            // מגירת ההיסטוריה צפה מעל התוכן הזה כ-overlay (Stack)
                            // כדי שלא תזיז את ההגדרות למטה כשהיא נפתחת.
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  BlocBuilder<SearchBloc, SearchState>(
                                    builder: (context, state) {
                                      final showCategory =
                                          !_searchAllCategories &&
                                              widget.bookTitle == null;

                                      // מצב לא-מתקדם: עץ קטגוריות בלבד (מלא) או ריק
                                      if (!state.isAdvancedSearchEnabled) {
                                        if (!showCategory) {
                                          return const SizedBox.shrink();
                                        }
                                        return CategoryTreeSelector(
                                          selectedFacets: _manualFacets,
                                          onSelectionChanged:
                                              _onManualFacetsChanged,
                                        );
                                      }

                                      // מצב מתקדם: אפשרויות + חלונית קטגוריות צד
                                      final advancedControls =
                                          AdvancedSearchControls(
                                        tab: _searchTab,
                                        compactMode: true,
                                        onEmptySubmit: _performSearch,
                                        inputFocusNotifier:
                                            _advancedControlsHasFocus,
                                      );
                                      final categoryPanel = showCategory &&
                                              widget.bookTitle == null
                                          ? CategoryTreeSelector(
                                              selectedFacets: _manualFacets,
                                              onSelectionChanged:
                                                  _onManualFacetsChanged,
                                            )
                                          : null;

                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          // כשיש פאנל קטגוריות (260px) + controls,
                                          // דורש לפחות ~480px — אחרת ערמה אנכית
                                          final useColumns =
                                              categoryPanel != null &&
                                                  constraints.maxWidth < 480;

                                          if (useColumns) {
                                            return SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  advancedControls,
                                                  const SizedBox(height: 12),
                                                  ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                            maxHeight: 220),
                                                    child: categoryPanel,
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: advancedControls,
                                                ),
                                              ),
                                              if (widget.bookTitle == null)
                                                AnimatedSize(
                                                  duration: const Duration(
                                                      milliseconds: 250),
                                                  curve: Curves.easeInOut,
                                                  child: categoryPanel != null
                                                      ? SizedBox(
                                                          width: 260,
                                                          height: constraints
                                                              .maxHeight,
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    right:
                                                                        12.0),
                                                            child:
                                                                categoryPanel,
                                                          ),
                                                        )
                                                      : const SizedBox.shrink(),
                                                ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  if (_showHistoryDropdown)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: TapRegion(
                                        groupId: _historyTapRegionGroupId,
                                        onTapOutside: (_) => setState(
                                            () => _showHistoryDropdown = false),
                                        child: _buildHistoryDropdown(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper class to provide the TantivyFullTextSearch interface
/// without actually using the full widget
class _SearchDialogWrapper {
  final SearchingTab tab;

  _SearchDialogWrapper({required this.tab});
}
