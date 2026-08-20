import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/core/messages/library_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/settings/l10n/settings_l10n_exports.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/combined_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';
import 'package:otzaria/widgets/misc/app_menu_exports.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';
import 'package:otzaria/workspaces/bloc/workspace_event.dart';

/// סוגר כרטיסיה ורושם אותה בהיסטוריה.
void closeTabWithHistory(BuildContext context, OpenedTab tab) {
  context.read<HistoryBloc>().add(AddHistory(tab));
  context.read<TabsBloc>().add(RemoveTab(tab));
}

/// סוגר חלונית אחת מלשונית מפוצלת; אחותה נשארת ככרטיסיה רגילה במקומה.
void closePaneWithHistory(BuildContext context, OpenedTab pane) {
  context.read<HistoryBloc>().add(AddHistory(pane));
  context.read<TabsBloc>().add(ClosePane(pane));
}

/// סוגר את כל הכרטיסיות שבבחירה המרובה בפעולה אחת.
void closeSelectedTabsWithHistory(BuildContext context) {
  final tabsBloc = context.read<TabsBloc>();
  final tabsToClose = List<OpenedTab>.from(tabsBloc.state.selectedTabs);
  if (tabsToClose.isEmpty) return;
  // אירוע קבוצתי אחד — אירועי AddHistory נפרדים מעובדים במקביל ועלולים
  // לדרוס זה את זה.
  context.read<HistoryBloc>().add(AddHistoryForTabs(tabsToClose));
  tabsBloc.add(RemoveTabs(tabsToClose));
}

/// תפריט ההקשר של כרטיסיה, משותף לרצועה העליונה ולעמודה האנכית.
///
/// [onCloseTab] / [onCloseSelectedTabs] מוזרקים כי הרצועה העליונה מקפיאה
/// את רוחב הכרטיסיות בסגירה, והעמודה האנכית לא.
List<AppContextMenuEntry> buildTabContextMenuEntries(
  BuildContext context,
  OpenedTab tab,
  TabsState state, {
  required void Function(OpenedTab tab) onCloseTab,
  required VoidCallback onCloseSelectedTabs,
}) {
  final entries = <AppContextMenuEntry>[
    AppContextMenuEntry(
      label: tab.isPinned
          ? context.settingsText('בטל הצמדת כרטיסיה')
          : context.settingsText('הצמד כרטיסיה'),
      onTap: () => context.read<TabsBloc>().add(TogglePinTab(tab)),
    ),
    // על טאב שנכלל בבחירה מרובה "סגור" הופך לסגירת כל הקבוצה (כמו בדפדפן).
    if (state.selectedTabs.length > 1 && state.selectedTabs.contains(tab))
      AppContextMenuEntry(
        label: context.settingsText(
          'סגור {count} כרטיסיות',
          args: {'count': state.selectedTabs.length},
        ),
        onTap: onCloseSelectedTabs,
      )
    else
      AppContextMenuEntry(
        label: context.settingsText('סגור'),
        onTap: () => onCloseTab(tab),
      ),
    AppContextMenuEntry(
      label: context.settingsText('סגור הכל'),
      onTap: () => context.read<TabsBloc>().add(CloseAllTabs()),
    ),
    AppContextMenuEntry(
      label: context.settingsText('סגור את האחרים'),
      onTap: () {
        final current = state.currentTab;
        if (current != null) {
          context.read<TabsBloc>().add(CloseOtherTabs(current));
        }
      },
    ),
    if (tab is! ToolTab || tab.isBuiltIn)
      AppContextMenuEntry(
        label: context.settingsText('שיכפול'),
        onTap: () => context.read<TabsBloc>().add(CloneTab(tab)),
      ),
    const AppContextMenuEntry.divider(),
  ];

  // טאב שכבר מפוצל אינו נכנס לפיצול נוסף: הפיצול הוא לשתי חלוניות בלבד.
  final otherTabs = tab is CombinedTab
      ? const <OpenedTab>[]
      : state.tabs.where((t) => t != tab && t is! CombinedTab).toList();
  if (otherTabs.isEmpty) {
    entries.add(
      AppContextMenuEntry(
        label: context.settingsText('הצג לצד'),
        enabled: false,
      ),
    );
  } else {
    entries.add(
      AppContextMenuEntry(
        label: context.settingsText('הצג לצד'),
        children: otherTabs
            .map(
              (otherTab) => AppContextMenuEntry(
                label: otherTab.title,
                onTap: () => context.read<TabsBloc>().add(
                  CreateCombinedTab(rightTab: tab, leftTab: otherTab),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  if (tab is CombinedTab) {
    // לחיצה ימנית אינה מחליפה טאב פעיל, לכן האירועים מקבלים אינדקס מפורש.
    final tabIndex = state.tabs.indexOf(tab);
    entries.addAll([
      AppContextMenuEntry(
        label: context.settingsText('סגור חלונית'),
        children: [
          for (final pane in leafPanes(tab))
            AppContextMenuEntry(
              label: pane.title,
              onTap: () => closePaneWithHistory(context, pane),
            ),
        ],
      ),
      AppContextMenuEntry(
        label: context.settingsText('החלף צדדים'),
        onTap: () => context.read<TabsBloc>().add(
          SwapSideBySideTabs(tabIndex: tabIndex),
        ),
      ),
      AppContextMenuEntry(
        label: context.settingsText('חזרה לתצוגה רגילה'),
        onTap: () => context.read<TabsBloc>().add(ExpandCombinedTab(tabIndex)),
      ),
    ]);
  }

  entries.addAll([
    const AppContextMenuEntry.divider(),
    _buildTabsPlacementEntry(context),
    AppContextMenuEntry(
      label: context.settingsText('כרטיסיות פתוחות'),
      // childrenBuilder + stream: הרשימה נבנית מחדש בכל שינוי במצב הכרטיסיות,
      // כך שסגירת כרטיסייה דרך ה-X מסירה את שורתה והתפריט נשאר פתוח.
      childrenBuilder: () => _openTabsMenuEntries(
        context,
        context.read<TabsBloc>().state.tabs,
        onCloseTab,
      ),
      childrenRefreshStream: context.read<TabsBloc>().stream,
    ),
    _buildMoveToWorkspaceMenuEntry(context, tab),
  ]);

  return entries;
}

/// החלפה בין רצועת הכרטיסיות שבכותרת לעמודה האנכית שבצד.
AppContextMenuEntry _buildTabsPlacementEntry(BuildContext context) {
  final onSide = context.read<SettingsBloc>().state.readingTabsOnSide;
  return AppContextMenuEntry(
    label: onSide
        ? context.settingsText('הצג כרטיסיות למעלה')
        : context.settingsText('הצג כרטיסיות בצד'),
    onTap: () => context.read<SettingsBloc>().add(
      UpdateReadingTabsPlacement(
        onSide
            ? SettingsRepository.readingTabsPlacementTop
            : SettingsRepository.readingTabsPlacementSide,
      ),
    ),
  );
}

List<AppContextMenuEntry> _openTabsMenuEntries(
  BuildContext context,
  List<OpenedTab> tabs,
  void Function(OpenedTab tab) onCloseTab,
) {
  // ללא מיון — הרשימה משקפת את סדר הכרטיסיות בשורת הכרטיסיות.
  return tabs.map((tab) {
    return AppContextMenuEntry(
      label: tab.title,
      onTap: () {
        final index = tabs.indexOf(tab);
        context.read<TabsBloc>().add(SetCurrentTab(index));
      },
      trailing: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: IconButton(
          tooltip: context.settingsText('סגור'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: const Icon(FluentIcons.dismiss_24_regular, size: 14),
          // סגירת הכרטיסייה מעדכנת את ה-TabsBloc; ה-childrenRefreshStream
          // יבנה מחדש את הרשימה ושורת הכרטיסייה תיעלם.
          onPressed: () => onCloseTab(tab),
          splashRadius: 16,
        ),
      ),
    );
  }).toList();
}

/// בונה פריט תפריט להעברת טאב לשולחן עבודה אחר
AppContextMenuEntry _buildMoveToWorkspaceMenuEntry(
  BuildContext context,
  OpenedTab tab,
) {
  final workspaceState = context.read<WorkspaceBloc>().state;

  final otherWorkspaces = workspaceState.workspaces
      .where((w) => w.id != workspaceState.activeWorkspaceId)
      .toList();

  if (otherWorkspaces.isEmpty) {
    return AppContextMenuEntry(
      label: context.settingsText('העבר לשולחן עבודה'),
      enabled: false,
    );
  }

  return AppContextMenuEntry(
    label: context.settingsText('העבר לשולחן עבודה'),
    children: otherWorkspaces.map((workspace) {
      return AppContextMenuEntry(
        label: workspace.name,
        onTap: () => _moveTabToWorkspace(context, tab, workspace.id),
      );
    }).toList(),
  );
}

/// מעביר טאב לשולחן עבודה אחר
void _moveTabToWorkspace(
  BuildContext context,
  OpenedTab tab,
  String targetWorkspaceId,
) {
  final tabsBloc = context.read<TabsBloc>();
  final workspaceBloc = context.read<WorkspaceBloc>();
  final tabsState = tabsBloc.state;
  final workspaceState = workspaceBloc.state;

  final targetWorkspace = workspaceState.workspaces.firstWhere(
    (w) => w.id == targetWorkspaceId,
  );

  tabsBloc.add(RemoveTab(tab));

  final currentTabs = tabsState.tabs.where((t) => t != tab).toList();
  final newActiveIndex = currentTabs.isEmpty
      ? 0
      : tabsState.currentTabIndex.clamp(0, currentTabs.length - 1);

  workspaceBloc.add(
    MoveTabToWorkspace(
      tab: tab,
      targetWorkspaceId: targetWorkspaceId,
      currentTabs: currentTabs,
      currentTabIndex: newActiveIndex,
    ),
  );

  UiSnack.show(LibraryMessages.tabMovedToWorkspace(targetWorkspace.name));
}
