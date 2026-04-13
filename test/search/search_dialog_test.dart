import 'package:bloc_test/bloc_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/history/bloc/history_state.dart';
import 'package:otzaria/indexing/bloc/indexing_bloc.dart';
import 'package:otzaria/indexing/bloc/indexing_event.dart';
import 'package:otzaria/indexing/bloc/indexing_state.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/search/view/search_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHistoryBloc extends MockBloc<HistoryEvent, HistoryState>
    implements HistoryBloc {}

class MockIndexingBloc extends MockBloc<IndexingEvent, IndexingState>
    implements IndexingBloc {}

class MockNavigationBloc extends MockBloc<NavigationEvent, NavigationState>
    implements NavigationBloc {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.init();
  });

  testWidgets('מגירת ההיסטוריה משתמשת ברקע של הדיאלוג',
      (WidgetTester tester) async {
    final historyBloc = MockHistoryBloc();
    final indexingBloc = MockIndexingBloc();
    final navigationBloc = MockNavigationBloc();
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFB85C38),
      ),
    );

    whenListen(
      historyBloc,
      const Stream<HistoryState>.empty(),
      initialState: HistoryLoaded([
        Bookmark(
          ref: 'משה',
          book: TextBook(title: 'משה'),
          index: 0,
          isSearch: true,
        ),
      ]),
    );
    whenListen(
      indexingBloc,
      const Stream<IndexingState>.empty(),
      initialState: IndexingInitial(),
    );
    whenListen(
      navigationBloc,
      const Stream<NavigationState>.empty(),
      initialState: const NavigationState(currentScreen: Screen.search),
    );

    addTearDown(() async {
      await historyBloc.close();
      await indexingBloc.close();
      await navigationBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<HistoryBloc>.value(value: historyBloc),
            BlocProvider<IndexingBloc>.value(value: indexingBloc),
            BlocProvider<NavigationBloc>.value(value: navigationBloc),
          ],
          child: const Scaffold(
            body: SearchDialog(),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('היסטוריית חיפושים'));
    await tester.pumpAndSettle();

    final dropdownContainer = tester.widget<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.margin == const EdgeInsets.only(top: 4) &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                theme.colorScheme.surfaceContainerHigh,
      ),
    );

    final decoration = dropdownContainer.decoration! as BoxDecoration;
    expect(decoration.color, theme.colorScheme.surfaceContainerHigh);
    expect(find.text('משה'), findsWidgets);
  });

  testWidgets('שחזור העדפה שמורה של שגיאות כתיב מדליק את האפשרות בדיאלוג',
      (WidgetTester tester) async {
    final historyBloc = MockHistoryBloc();
    final indexingBloc = MockIndexingBloc();
    final navigationBloc = MockNavigationBloc();

    Settings.setValue<String>('key-last-search-mode', 'advanced');
    Settings.setValue<bool>('key-last-search-typo-tolerance', true);

    whenListen(
      historyBloc,
      const Stream<HistoryState>.empty(),
      initialState: HistoryLoaded([]),
    );
    whenListen(
      indexingBloc,
      const Stream<IndexingState>.empty(),
      initialState: IndexingInitial(),
    );
    whenListen(
      navigationBloc,
      const Stream<NavigationState>.empty(),
      initialState: const NavigationState(currentScreen: Screen.search),
    );

    addTearDown(() async {
      Settings.setValue<bool>('key-last-search-typo-tolerance', false);
      await historyBloc.close();
      await indexingBloc.close();
      await navigationBloc.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<HistoryBloc>.value(value: historyBloc),
            BlocProvider<IndexingBloc>.value(value: indexingBloc),
            BlocProvider<NavigationBloc>.value(value: navigationBloc),
          ],
          child: const Scaffold(
            body: SearchDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final typoToggle = find.ancestor(
      of: find.text('שגיאות כתיב'),
      matching: find.byType(InkWell),
    );
    expect(typoToggle, findsOneWidget);
    expect(
      find.descendant(
        of: typoToggle,
        matching: find.byIcon(FluentIcons.checkmark_24_regular),
      ),
      findsOneWidget,
    );
  });
}
