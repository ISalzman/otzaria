import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/bloc/indexing_bloc.dart';
import 'package:otzaria/indexing/bloc/indexing_event.dart';
import 'package:otzaria/indexing/bloc/indexing_state.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/search/bloc/search_bloc.dart';
import 'package:otzaria/search/bloc/search_event.dart';
import 'package:otzaria/search/bloc/search_state.dart';
import 'package:otzaria/search/models/external_search_status.dart';
import 'package:otzaria/search/view/full_text_settings_widgets.dart';
import 'package:otzaria/search/view/tantivy_full_text_search.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';

import '../test_helpers/memory_cache_provider.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _MockTabsBloc extends MockBloc<TabsEvent, TabsState>
    implements TabsBloc {}

class _MockNavigationBloc extends MockBloc<NavigationEvent, NavigationState>
    implements NavigationBloc {}

class _MockIndexingBloc extends MockBloc<IndexingEvent, IndexingState>
    implements IndexingBloc {}

class _SearchBloc extends SearchBloc {
  _SearchBloc(SearchState state) {
    emit(state);
  }

  @override
  void add(SearchEvent event) {
    if (event is! LoadMoreResults) super.add(event);
  }
}

void main() {
  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  Future<void> pumpSearch(
    WidgetTester tester, {
    required double width,
  }) async {
    final searchBloc = _SearchBloc(
      const SearchState(searchQuery: 'בדיקה', totalResults: 12),
    );
    final settingsBloc = _MockSettingsBloc();
    final tabsBloc = _MockTabsBloc();
    final navigationBloc = _MockNavigationBloc();
    final indexingBloc = _MockIndexingBloc();
    final tab = SearchingTab('חיפוש', '', searchBloc: searchBloc);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 700);
    tab.isLeftPaneOpen.value = false;
    tab.externalSearchStatus.value = const ExternalSearchStatus(
      sourceTitle: 'היברובוקס',
      loading: false,
      books: 3,
      hits: 7,
    );

    whenListen(
      settingsBloc,
      const Stream<SettingsState>.empty(),
      initialState: SettingsState.initial(),
    );
    whenListen(
      tabsBloc,
      const Stream<TabsState>.empty(),
      initialState: TabsState(
        tabs: [tab],
        currentTabIndex: 0,
        rawActivePane: tab,
      ),
    );
    whenListen(
      navigationBloc,
      const Stream<NavigationState>.empty(),
      initialState: const NavigationState(currentScreen: Screen.search),
    );
    whenListen(
      indexingBloc,
      const Stream<IndexingState>.empty(),
      initialState: IndexingInitial(),
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tab.dispose();
      await searchBloc.close();
      await settingsBloc.close();
      await tabsBloc.close();
      await navigationBloc.close();
      await indexingBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SearchBloc>.value(value: searchBloc),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<TabsBloc>.value(value: tabsBloc),
            BlocProvider<NavigationBloc>.value(value: navigationBloc),
            BlocProvider<IndexingBloc>.value(value: indexingBloc),
          ],
          child: Scaffold(
            body: TantivyFullTextSearch(tab: tab),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('הסרגל הרחב שומר ספירות ומיקום של תוצאות חיצוניות', (
    tester,
  ) async {
    await pumpSearch(tester, width: 1200);

    expect(find.textContaining('אוצריא: 0/12'), findsOneWidget);
    expect(find.textContaining('היברובוקס: 3 ספרים'), findsOneWidget);
    expect(find.byType(ExternalResultsPositionControl), findsOneWidget);
    expect(
      tester
          .widget<ExternalResultsPositionControl>(
            find.byType(ExternalResultsPositionControl),
          )
          .compact,
      isFalse,
    );
    expect(find.text('תוצאות מהיברובוקס מאוחרות'), findsOneWidget);
  });

  testWidgets('הסרגל המכווץ שומר על הפקד החיצוני במצב קומפקטי', (
    tester,
  ) async {
    await pumpSearch(tester, width: 850);

    final control = tester.widget<ExternalResultsPositionControl>(
      find.byType(ExternalResultsPositionControl),
    );
    expect(control.compact, isTrue);
    expect(find.textContaining('אוצריא: 0/12'), findsOneWidget);
    expect(find.textContaining('היברובוקס: 3 ספרים'), findsOneWidget);
    final menu = tester.widget<AppPopupMenuButton<bool>>(
      find.descendant(
        of: find.byType(ExternalResultsPositionControl),
        matching: find.byType(AppPopupMenuButton<bool>),
      ),
    );
    expect(menu.tooltip, 'מיקום תוצאות היברובוקס');
  });
}
