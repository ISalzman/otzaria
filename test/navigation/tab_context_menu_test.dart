import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/history/bloc/history_state.dart';
import 'package:otzaria/navigation/view/tab_context_menu.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';
import 'package:otzaria/workspaces/bloc/workspace_state.dart';

class _StubTab extends OpenedTab {
  _StubTab(super.title);

  @override
  Map<String, dynamic> toJson() => {'type': '_StubTab', 'title': title};
}

void main() {
  late _TestTabsBloc tabsBloc;
  late _TestSettingsBloc settingsBloc;
  late _TestHistoryBloc historyBloc;
  late _TestWorkspaceBloc workspaceBloc;

  /// בונה את פריטי התפריט של [tab] מתוך עץ ווידג'טים עם כל ה-blocs.
  Future<List<AppContextMenuEntry>> buildEntries(
    WidgetTester tester, {
    required OpenedTab tab,
    required TabsState state,
  }) async {
    tabsBloc = _TestTabsBloc(state);
    settingsBloc = _TestSettingsBloc(SettingsState.initial());
    historyBloc = _TestHistoryBloc();
    workspaceBloc = _TestWorkspaceBloc();
    addTearDown(() async {
      await tabsBloc.close();
      await settingsBloc.close();
      await historyBloc.close();
      await workspaceBloc.close();
    });

    late List<AppContextMenuEntry> entries;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<TabsBloc>.value(value: tabsBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
          BlocProvider<HistoryBloc>.value(value: historyBloc),
          BlocProvider<WorkspaceBloc>.value(value: workspaceBloc),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              entries = buildTabContextMenuEntries(
                context,
                tab,
                state,
                onCloseTab: (_) {},
                onCloseSelectedTabs: () {},
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return entries;
  }

  AppContextMenuEntry entryOf(
    List<AppContextMenuEntry> entries,
    String label,
  ) => entries.firstWhere((entry) => entry.label == label);

  testWidgets('"סגור את האחרים" שומר את הכרטיסייה שנלחצה, לא את הפעילה', (
    tester,
  ) async {
    final tabs = [_StubTab('ספר א'), _StubTab('ספר ב'), _StubTab('ספר ג')];
    final entries = await buildEntries(
      tester,
      tab: tabs[2],
      state: TabsState(tabs: tabs, currentTabIndex: 0),
    );

    entryOf(entries, 'סגור את האחרים').onTap!();
    await tester.pump();

    final event = tabsBloc.addedEvents.whereType<CloseOtherTabs>().single;
    expect(
      event.keepTab,
      same(tabs[2]),
      reason:
          'לחיצה ימנית אינה מחליפה כרטיסייה פעילה — הפעולה חייבת לשמור '
          'את הכרטיסייה שעליה נפתח התפריט (issue #1094)',
    );
  });

  testWidgets('"סגור את האחרים" על הכרטיסייה הפעילה שומר עליה', (tester) async {
    final tabs = [_StubTab('ספר א'), _StubTab('ספר ב')];
    final entries = await buildEntries(
      tester,
      tab: tabs[1],
      state: TabsState(tabs: tabs, currentTabIndex: 1),
    );

    entryOf(entries, 'סגור את האחרים').onTap!();
    await tester.pump();

    expect(
      tabsBloc.addedEvents.whereType<CloseOtherTabs>().single.keepTab,
      same(tabs[1]),
    );
  });
}

class _TestTabsBloc extends Cubit<TabsState> implements TabsBloc {
  _TestTabsBloc(super.initialState);

  final List<TabsEvent> addedEvents = [];

  @override
  void add(TabsEvent event) => addedEvents.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSettingsBloc extends Cubit<SettingsState> implements SettingsBloc {
  _TestSettingsBloc(super.initialState);

  @override
  void add(SettingsEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestWorkspaceBloc extends Cubit<WorkspaceState>
    implements WorkspaceBloc {
  _TestWorkspaceBloc() : super(WorkspaceState.initial());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHistoryBloc extends Cubit<HistoryState> implements HistoryBloc {
  _TestHistoryBloc() : super(HistoryInitial());

  @override
  void add(HistoryEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
