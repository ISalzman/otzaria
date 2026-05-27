import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/history/bloc/history_state.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/shortcuts/keyboard_shortcuts.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:provider/provider.dart';
import '../helpers/memory_settings_cache.dart';

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

class _StubTabsBloc extends Cubit<TabsState> implements TabsBloc {
  _StubTabsBloc(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubHistoryBloc extends Bloc<HistoryEvent, HistoryState>
    implements HistoryBloc {
  _StubHistoryBloc() : super(HistoryInitial()) {
    on<HistoryEvent>((_, __) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubNavigationBloc extends Bloc<NavigationEvent, NavigationState>
    implements NavigationBloc {
  _StubNavigationBloc()
      : super(const NavigationState(currentScreen: Screen.reading)) {
    on<NavigationEvent>((_, __) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyboardShortcuts', () {
    late MockSettingsBloc settingsBloc;
    late StreamController<SettingsState> settingsController;

    setUp(() {
      settingsBloc = MockSettingsBloc();
      settingsController = StreamController<SettingsState>.broadcast();

      whenListen(
        settingsBloc,
        settingsController.stream,
        initialState: SettingsState.initial(),
      );
    });

    tearDown(() async {
      await settingsController.close();
    });

    testWidgets('לא זורק שגיאה בזמן rebuild של קיצורים כששדה טקסט מחזיק focus',
        (tester) async {
      await tester.pumpWidget(
        BlocProvider<SettingsBloc>.value(
          value: settingsBloc,
          child: MaterialApp(
            home: Scaffold(
              body: KeyboardShortcuts(
                onFindRefRequested: () {},
                child: const TextField(),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, isNotNull);

      // עדכון shortcuts מטריגר rebuild של ה-FocusScope; לפני התיקון
      // FocusScopeNode חדש בכל rebuild היה זורק שגיאה כששדה טקסט מחזיק focus.
      settingsController.add(
        SettingsState.initial().copyWith(
          shortcuts: const {
            'key-shortcut-open-library-browser': 'ctrl+shift+l',
          },
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('KeyboardShortcuts - קיצורי חלוניות (Ctrl+Shift+L/C)', () {
    late MockSettingsBloc settingsBlocLocal;
    late StreamController<SettingsState> settingsControllerLocal;

    setUpAll(() async {
      await Settings.init(cacheProvider: MemorySettingsCache());
    });

    setUp(() {
      FocusRepository().resetForTesting();
      settingsBlocLocal = MockSettingsBloc();
      settingsControllerLocal = StreamController<SettingsState>.broadcast();
      whenListen(
        settingsBlocLocal,
        settingsControllerLocal.stream,
        initialState: SettingsState.initial().copyWith(
          shortcuts: const {
            'key-shortcut-toggle-nav-pane': 'ctrl+shift+l',
            'key-shortcut-toggle-commentators-pane': 'ctrl+shift+c',
          },
        ),
      );
    });

    tearDown(() async {
      await settingsControllerLocal.close();
      FocusRepository().resetForTesting();
    });

    Future<void> pumpWithTab(WidgetTester tester, OpenedTab tab) async {
      final tabsBloc = _StubTabsBloc(
        TabsState(tabs: [tab], currentTabIndex: 0),
      );
      final historyBloc = _StubHistoryBloc();
      final navigationBloc = _StubNavigationBloc();
      addTearDown(() async {
        await tabsBloc.close();
        await historyBloc.close();
        await navigationBloc.close();
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBlocLocal),
            BlocProvider<TabsBloc>.value(value: tabsBloc),
            BlocProvider<HistoryBloc>.value(value: historyBloc),
            BlocProvider<NavigationBloc>.value(value: navigationBloc),
            Provider<FocusRepository>.value(value: FocusRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: KeyboardShortcuts(
                onFindRefRequested: () {},
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> sendCtrlShift(
        WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(key);
      await tester.sendKeyUpEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    testWidgets('Ctrl+Shift+L ב-PdfBookTab מטוגל את toggleNavPaneNotifier',
        (tester) async {
      final tab = PdfBookTab(
        book: PdfBook(title: 'ספר PDF', path: '/x.pdf'),
        pageNumber: 1,
      );
      addTearDown(tab.dispose);

      await pumpWithTab(tester, tab);

      expect(tab.toggleNavPaneNotifier.value, 0);
      await sendCtrlShift(tester, LogicalKeyboardKey.keyL);
      expect(tab.toggleNavPaneNotifier.value, 1);

      await sendCtrlShift(tester, LogicalKeyboardKey.keyL);
      expect(tab.toggleNavPaneNotifier.value, 2);
    });

    testWidgets(
        'Ctrl+Shift+C ב-PdfBookTab מטוגל את toggleCommentatorsPaneNotifier '
        '(תיקון הבאג: PR המקורי בלע את האירוע ב-PDF)', (tester) async {
      final tab = PdfBookTab(
        book: PdfBook(title: 'ספר PDF', path: '/x.pdf'),
        pageNumber: 1,
      );
      addTearDown(tab.dispose);

      await pumpWithTab(tester, tab);

      expect(tab.toggleCommentatorsPaneNotifier.value, 0);
      await sendCtrlShift(tester, LogicalKeyboardKey.keyC);
      expect(tab.toggleCommentatorsPaneNotifier.value, 1);
    });
  });
}
