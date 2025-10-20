import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart' show Screen;
import 'package:otzaria/pdf_book/pdf_book_screen.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/search/view/full_text_search_screen.dart';
import 'package:otzaria/text_book/view/text_book_screen.dart';
import 'package:otzaria/utils/text_manipulation.dart';
import 'package:otzaria/workspaces/view/workspace_switcher_dialog.dart';
import 'package:otzaria/history/history_dialog.dart';
import 'package:otzaria/bookmarks/bookmarks_dialog.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/widgets/scrollable_tab_bar.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_event.dart';
import 'package:otzaria/settings/settings_state.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

const double _kAppBarControlsWidth = 125.0;

class _ReadingScreenState extends State<ReadingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // האם יש אוברפלואו בטאבים (גלילה)? משמש לקביעת placeholder לדינמיות מרכוז/התפרשות
  bool _tabsOverflow = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Check if widget is still mounted before accessing context
    if (mounted) {
      try {
        context.read<HistoryBloc>().add(FlushHistory());
      } catch (e) {
        // Ignore errors during disposal
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      context.read<HistoryBloc>().add(FlushHistory());
      context.read<TabsBloc>().add(const SaveTabs());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TabsBloc, TabsState>(
      listener: (context, state) {
        if (state.hasOpenTabs) {
          context
              .read<HistoryBloc>()
              .add(CaptureStateForHistory(state.currentTab!));
        }
      },
      listenWhen: (previous, current) =>
          previous.currentTabIndex != current.currentTabIndex,
      child: BlocBuilder<TabsBloc, TabsState>(
        builder: (context, state) {
          if (!state.hasOpenTabs) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('לא נבחרו ספרים'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      onPressed: () {
                        context.read<NavigationBloc>().add(
                              const NavigateToScreen(Screen.library),
                            );
                      },
                      child: const Text('דפדף בספרייה'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      onPressed: () {
                        _showSaveWorkspaceDialog(context);
                      },
                      child: const Text('החלף שולחן עבודה'),
                    ),
                  ),
                  // קו מפריד
                  Container(
                    height: 1,
                    width: 200,
                    color: Colors.grey.shade400,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      onPressed: () {
                        _showHistoryDialog(context);
                      },
                      child: const Text('הצג היסטוריה'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      onPressed: () {
                        _showBookmarksDialog(context);
                      },
                      child: const Text('הצג סימניות'),
                    ),
                  )
                ],
              ),
            );
          }

          return Builder(
            builder: (context) {
              final controller = TabController(
                length: state.tabs.length,
                vsync: this,
                initialIndex: state.currentTabIndex,
              );

              controller.addListener(() {
                if (controller.indexIsChanging &&
                    state.currentTabIndex < state.tabs.length) {
                  // שמירת המצב הנוכחי לפני המעבר לטאב אחר
                  debugPrint(
                      'DEBUG: מעבר בין טאבים - שמירת מצב טאב ${state.currentTabIndex}');
                  context.read<HistoryBloc>().add(CaptureStateForHistory(
                      state.tabs[state.currentTabIndex]));
                }
                if (controller.index != state.currentTabIndex) {
                  debugPrint('DEBUG: עדכון טאב נוכחי ל-${controller.index}');
                  context.read<TabsBloc>().add(SetCurrentTab(controller.index));
                }
              });

              return Scaffold(
                appBar: AppBar(
                  // 1. משתמשים בקבוע שהגדרנו עבור הרוחב
                  leadingWidth: _kAppBarControlsWidth,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // קבוצת היסטוריה וסימניות
                      IconButton(
                        icon: const Icon(Icons.history),
                        tooltip: 'הצג היסטוריה',
                        onPressed: () => _showHistoryDialog(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark),
                        tooltip: 'הצג סימניות',
                        onPressed: () => _showBookmarksDialog(context),
                      ),
                      // קו מפריד
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.shade400,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                      ),
                      // קבוצת שולחן עבודה עם אנימציה
                      IconButton(
                        icon: const Icon(Icons.add_to_queue),
                        tooltip: 'החלף שולחן עבודה',
                        onPressed: () => _showSaveWorkspaceDialog(context),
                      ),
                    ],
                  ),
                  titleSpacing: 0,
                  centerTitle: true,
                  title: Container(
                    constraints: const BoxConstraints(maxHeight: 50),
                    child: ScrollableTabBarWithArrows(
                      controller: controller,
                      tabAlignment: TabAlignment.center,
                      onOverflowChanged: (overflow) {
                        if (mounted) {
                          setState(() => _tabsOverflow = overflow);
                        }
                      },
                      tabs: state.tabs
                          .map((tab) => _buildTab(context, tab, state))
                          .toList(),
                    ),
                  ),
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  // כאשר אין גלילה — מוסיפים placeholder משמאל כדי למרכז באמת ביחס למסך כולו
                  // כאשר יש גלילה — מבטלים אותו כדי לאפשר התפשטות גם לצד שמאל
                  // שומרים תמיד מקום קבוע לימין כדי למנוע שינויי רוחב פתאומיים
                  actions: [
                    // רווח למרכוז (רק כאשר אין גלילה)
                    if (!_tabsOverflow)
                      const SizedBox(width: _kAppBarControlsWidth - 56), // מפחיתים את רוחב כפתור ההגדרות
                    // כפתור הגדרות בצד שמאל של שורת הטאבים (צמוד לשמאל לחלוטין)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'הגדרות תצוגת הספרים',
                        onPressed: () => _showReadingSettingsDialog(context, state),
                        style: IconButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // centerTitle לא נדרש כאשר הטאבים נמצאים ב-bottom

                  // 2. משתמשים באותו קבוע בדיוק עבור ווידג'ט הדמה
                  // הוסר הרווח המלאכותי מצד שמאל כדי לאפשר לטאבים לתפוס רוחב מלא בעת הצורך
                ),
                body: SizedBox.fromSize(
                  size: MediaQuery.of(context).size,
                  child: TabBarView(
                    controller: controller,
                    children:
                        state.tabs.map((tab) => _buildTabView(tab)).toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTabView(OpenedTab tab) {
    if (tab is PdfBookTab) {
      return PdfBookScreen(
        key: PageStorageKey(tab),
        tab: tab,
      );
    } else if (tab is TextBookTab) {
      return BlocProvider.value(
          value: tab.bloc,
          child: TextBookViewerBloc(
            openBookCallback: (tab, {int index = 1}) {
              context.read<TabsBloc>().add(AddTab(tab));
            },
            tab: tab,
          ));
    } else if (tab is SearchingTab) {
      return FullTextSearchScreen(
        tab: tab,
        openBookCallback: (tab, {int index = 1}) {
          context.read<TabsBloc>().add(AddTab(tab));
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTab(BuildContext context, OpenedTab tab, TabsState state) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        if (event.buttons == 4) {
          closeTab(tab, context);
        }
      },
      child: ContextMenuRegion(
        contextMenu: ContextMenu(
          entries: [
            MenuItem(label: 'סגור', onSelected: () => closeTab(tab, context)),
            MenuItem(
                label: 'סגור הכל',
                onSelected: () => closeAllTabs(state, context)),
            MenuItem(
              label: 'סגור את האחרים',
              onSelected: () => closeAllTabsButCurrent(state, context),
            ),
            MenuItem(
              label: 'שיכפול',
              onSelected: () => context.read<TabsBloc>().add(CloneTab(tab)),
            ),
            MenuItem.submenu(
              label: 'רשימת הכרטיסיות ',
              items: _getMenuItems(state.tabs, context),
            )
          ],
        ),
        child: Draggable<OpenedTab>(
          axis: Axis.horizontal,
          data: tab,
          childWhenDragging: const SizedBox.shrink(),
          feedback: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
              child: Text(
                tab is SearchingTab
                    ? '${tab.title}:  ${tab.queryController.text}'
                    : tab.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          child: DragTarget<OpenedTab>(
            onAcceptWithDetails: (draggedTab) {
              if (draggedTab.data == tab) return;
              final newIndex = state.tabs.indexOf(tab);
              context.read<TabsBloc>().add(MoveTab(draggedTab.data, newIndex));
            },
            builder: (context, candidateData, rejectedData) => Tab(
              child: Row(
                children: [
                  if (tab is SearchingTab)
                    ValueListenableBuilder(
                      valueListenable: tab.queryController,
                      builder: (context, value, child) => Tooltip(
                        message: '${tab.title}:  ${tab.queryController.text}',
                        child: Text(
                          truncate(
                              '${tab.title}:  ${tab.queryController.text}', 12),
                        ),
                      ),
                    )
                  else if (tab is PdfBookTab)
                    Tooltip(
                      message: tab.title,
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.picture_as_pdf, size: 16),
                          ),
                          Text(truncate(tab.title, 12)),
                        ],
                      ),
                    )
                  else
                    Tooltip(
                        message: tab.title,
                        child: Text(truncate(tab.title, 12))),
                  Tooltip(
                    preferBelow: false,
                    message:
                        (Settings.getValue<String>('key-shortcut-close-tab') ??
                                'ctrl+w')
                            .toUpperCase(),
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 25,
                        minHeight: 25,
                        maxWidth: 25,
                        maxHeight: 25,
                      ),
                      onPressed: () => closeTab(tab, context),
                      icon: const Icon(Icons.close, size: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ContextMenuEntry> _getMenuItems(
      List<OpenedTab> tabs, BuildContext context) {
    List<MenuItem> items = tabs
        .map((tab) => MenuItem(
              label: tab.title,
              onSelected: () {
                final index = tabs.indexOf(tab);
                context.read<TabsBloc>().add(SetCurrentTab(index));
              },
            ))
        .toList();

    items.sort((a, b) => a.label.compareTo(b.label));
    return items;
  }

  void _showSaveWorkspaceDialog(BuildContext context) {
    context.read<HistoryBloc>().add(FlushHistory());
    showDialog(
      context: context,
      builder: (context) => const WorkspaceSwitcherDialog(),
    );
  }

  void closeTab(OpenedTab tab, BuildContext context) {
    context.read<HistoryBloc>().add(AddHistory(tab));
    context.read<TabsBloc>().add(RemoveTab(tab));
  }

  void closeAllTabs(TabsState state, BuildContext context) {
    for (final tab in state.tabs) {
      context.read<HistoryBloc>().add(AddHistory(tab));
    }
    context.read<TabsBloc>().add(CloseAllTabs());
  }

  void closeAllTabsButCurrent(TabsState state, BuildContext context) {
    final current = state.tabs[state.currentTabIndex];
    final toClose = state.tabs.where((t) => t != current).toList();
    for (final tab in toClose) {
      context.read<HistoryBloc>().add(AddHistory(tab));
    }
    context.read<TabsBloc>().add(CloseOtherTabs(current));
  }

  void _showHistoryDialog(BuildContext context) {
    context.read<HistoryBloc>().add(FlushHistory());
    showDialog(
      context: context,
      builder: (context) => const HistoryDialog(),
    );
  }

  void _showBookmarksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BookmarksDialog(),
    );
  }

  void _showReadingSettingsDialog(BuildContext context, TabsState tabsState) {
    showDialog(
      context: context,
      builder: (context) => BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          return AlertDialog(
            title: const Text(
              'הגדרות תצוגת הספרים',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // כותרת: הגדרות גופן ועיצוב
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: const Text(
                        'הגדרות גופן ועיצוב',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    
                    // גודל גופן והגופן בשורה אחת
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // גודל גופן - 3/4
                          Expanded(
                            flex: 3,
                            child: StatefulBuilder(
                              builder: (context, setState) {
                                double currentFontSize = settingsState.fontSize.clamp(15, 60);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.format_size),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'גודל גופן התחלתי',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        ),
                                        Text(
                                          currentFontSize.toStringAsFixed(0),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Slider(
                                      value: currentFontSize,
                                      min: 15,
                                      max: 60,
                                      divisions: 45,
                                      label: currentFontSize.toStringAsFixed(0),
                                      onChanged: (value) {
                                        setState(() {});
                                        context.read<SettingsBloc>().add(UpdateFontSize(value));
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          // גופן - 1/4
                          Expanded(
                            flex: 1,
                            child: StatefulBuilder(
                              builder: (context, setState) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.font_download_outlined),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'גופן',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: settingsState.fontFamily,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      dropdownColor: Theme.of(context).colorScheme.surface,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'TaameyDavidCLM', child: Text('דוד')),
                                        DropdownMenuItem(value: 'FrankRuhlCLM', child: Text('פרנק-רוהל')),
                                        DropdownMenuItem(value: 'TaameyAshkenaz', child: Text('טעמי אשכנז')),
                                        DropdownMenuItem(value: 'KeterYG', child: Text('כתר')),
                                        DropdownMenuItem(value: 'Shofar', child: Text('שופר')),
                                        DropdownMenuItem(value: 'NotoSerifHebrew', child: Text('נוטו')),
                                        DropdownMenuItem(value: 'Tinos', child: Text('טינוס')),
                                        DropdownMenuItem(value: 'NotoRashiHebrew', child: Text('רש"י')),
                                        DropdownMenuItem(value: 'Candara', child: Text('קנדרה')),
                                        DropdownMenuItem(value: 'roboto', child: Text('רובוטו')),
                                        DropdownMenuItem(value: 'Calibri', child: Text('קליברי')),
                                        DropdownMenuItem(value: 'Arial', child: Text('אריאל')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          context.read<SettingsBloc>().add(UpdateFontFamily(value));
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    
                    // רוחב השוליים בצידי הטקסט
                    StatefulBuilder(
                      builder: (context, setState) {
                        double currentPadding = settingsState.paddingSize;
                        return Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.horizontal_distribute),
                              title: const Text('רוחב השוליים בצידי הטקסט'),
                              trailing: Text(
                                currentPadding.toStringAsFixed(0),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Slider(
                                value: currentPadding,
                                min: 0,
                                max: 500,
                                divisions: 250,
                                label: currentPadding.toStringAsFixed(0),
                                onChanged: (value) {
                                  setState(() {});
                                  context.read<SettingsBloc>().add(UpdatePaddingSize(value));
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    // כותרת: הסרת ניקוד וטעמים
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: const Text(
                        'הסרת ניקוד וטעמים',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    
                    // הצגת טעמי המקרא
                    SwitchListTile(
                      title: const Text('הצגת טעמי המקרא'),
                      subtitle: Text(settingsState.showTeamim
                          ? 'המקרא יוצג עם טעמים'
                          : 'המקרא יוצג ללא טעמים'),
                      value: settingsState.showTeamim,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(UpdateShowTeamim(value));
                      },
                    ),
                    const Divider(),
                    
                    // הסרת ניקוד כברירת מחדל
                    SwitchListTile(
                      title: const Text('הסרת ניקוד כברירת מחדל'),
                      subtitle: Text(settingsState.defaultRemoveNikud
                          ? 'הניקוד יוסר כברירת מחדל'
                          : 'הניקוד יוצג כברירת מחדל'),
                      value: settingsState.defaultRemoveNikud,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(UpdateDefaultRemoveNikud(value));
                      },
                    ),
                    if (settingsState.defaultRemoveNikud)
                      Padding(
                        padding: const EdgeInsets.only(right: 32.0),
                        child: CheckboxListTile(
                          title: const Text('הסרת ניקוד מספרי התנ"ך'),
                          subtitle: const Text('גם ספרי התנ"ך יוצגו ללא ניקוד'),
                          value: settingsState.removeNikudFromTanach,
                          onChanged: (bool? value) {
                            if (value != null) {
                              context.read<SettingsBloc>().add(
                                    UpdateRemoveNikudFromTanach(value),
                                  );
                            }
                          },
                        ),
                      ),
                    
                    // כותרת: התנהגות סרגל צד
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: const Text(
                        'התנהגות סרגל צד',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    
                    // הצמדת סרגל צד
                    SwitchListTile(
                      title: const Text('הצמדת סרגל צד'),
                      subtitle: Text(settingsState.pinSidebar
                          ? 'סרגל הצד יוצמד תמיד'
                          : 'סרגל הצד יפעל כרגיל'),
                      value: settingsState.pinSidebar,
                      onChanged: (value) {
                        context.read<SettingsBloc>().add(UpdatePinSidebar(value));
                        if (value) {
                          context.read<SettingsBloc>().add(const UpdateDefaultSidebarOpen(true));
                        }
                      },
                    ),
                    const Divider(),
                    
                    // פתיחת סרגל צד
                    SwitchListTile(
                      title: const Text('פתיחת סרגל צד כברירת מחדל'),
                      subtitle: Text(settingsState.defaultSidebarOpen
                          ? 'סרגל הצד יפתח אוטומטית'
                          : 'סרגל הצד ישאר סגור'),
                      value: settingsState.defaultSidebarOpen,
                      onChanged: settingsState.pinSidebar
                          ? null
                          : (value) {
                              context.read<SettingsBloc>().add(UpdateDefaultSidebarOpen(value));
                            },
                    ),
                    const Divider(),
                    
                    // ברירת מחדל להצגת מפרשים
                    StatefulBuilder(
                      builder: (context, setState) {
                        final splitedView = Settings.getValue<bool>('key-splited-view') ?? false;
                        return SwitchListTile(
                          title: const Text('ברירת המחדל להצגת המפרשים'),
                          subtitle: Text(splitedView
                              ? 'המפרשים יוצגו לצד הטקסט'
                              : 'המפרשים יוצגו מתחת הטקסט'),
                          value: splitedView,
                          onChanged: (value) {
                            setState(() {
                              Settings.setValue<bool>('key-splited-view', value);
                            });
                          },
                        );
                      },
                    ),
                    
                    // הגדרות העתקה
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: const Text(
                        'הגדרות העתקה',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    
                    // העתקה עם כותרות ועיצוב בשורה אחת
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: StatefulBuilder(
                        builder: (context, setState) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // העתקה עם כותרות - 1/2
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.content_copy),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'העתקה עם כותרות',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: settingsState.copyWithHeaders,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      dropdownColor: Theme.of(context).colorScheme.surface,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(value: 'none', child: Text('ללא')),
                                        DropdownMenuItem(
                                            value: 'book_name',
                                            child: Text('שם הספר בלבד')),
                                        DropdownMenuItem(
                                            value: 'book_and_path',
                                            child: Text('שם הספר+נתיב')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          context.read<SettingsBloc>().add(UpdateCopyWithHeaders(value));
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // עיצוב העתקה - 1/2
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.format_align_right),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'עיצוב העתקה',
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: settingsState.copyHeaderFormat,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      dropdownColor: Theme.of(context).colorScheme.surface,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'same_line_after_brackets',
                                            child: Text('אותה שורה אחרי (עם סוגריים)')),
                                        DropdownMenuItem(
                                            value: 'same_line_after_no_brackets',
                                            child: Text('אותה שורה אחרי (בלי סוגריים)')),
                                        DropdownMenuItem(
                                            value: 'same_line_before_brackets',
                                            child: Text('אותה שורה לפני (עם סוגריים)')),
                                        DropdownMenuItem(
                                            value: 'same_line_before_no_brackets',
                                            child: Text('אותה שורה לפני (בלי סוגריים)')),
                                        DropdownMenuItem(
                                            value: 'separate_line_after',
                                            child: Text('פסקה נפרדת אחרי')),
                                        DropdownMenuItem(
                                            value: 'separate_line_before',
                                            child: Text('פסקה נפרדת לפני')),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          context.read<SettingsBloc>().add(UpdateCopyHeaderFormat(value));
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    
                    // הגדרות עורך טקסטים
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: const Text(
                        'הגדרות עורך טקסטים',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.start,
                      ),
                    ),
                    
                    StatefulBuilder(
                      builder: (context, setState) {
                        double previewDebounce = Settings.getValue<double>(
                                'key-editor-preview-debounce') ??
                            150.0;
                        double cleanupDays = Settings.getValue<double>(
                                'key-editor-draft-cleanup-days') ??
                            30.0;
                        double draftsQuota =
                            Settings.getValue<double>('key-editor-drafts-quota') ?? 100.0;

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // עיכוב תצוגה מקדימה
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.timer_outlined),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'זמן עיכוב במילישניות',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                      Text(
                                        '${previewDebounce.toInt()}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: previewDebounce,
                                    min: 50,
                                    max: 300,
                                    divisions: 5,
                                    label: previewDebounce.toInt().toString(),
                                    onChanged: (value) {
                                      setState(() => previewDebounce = value);
                                      Settings.setValue<double>(
                                          'key-editor-preview-debounce', value);
                                    },
                                  ),
                                ],
                              ),
                              const Divider(),
                              
                              // ניקוי טיוטות ישנות
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.delete_sweep_outlined),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'ניקוי טיוטות ישנות (ימים)',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                      Text(
                                        '${cleanupDays.toInt()}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: cleanupDays,
                                    min: 7,
                                    max: 90,
                                    divisions: 12,
                                    label: cleanupDays.toInt().toString(),
                                    onChanged: (value) {
                                      setState(() => cleanupDays = value);
                                      Settings.setValue<double>(
                                          'key-editor-draft-cleanup-days', value);
                                    },
                                  ),
                                ],
                              ),
                              const Divider(),
                              
                              // מכסת טיוטות
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.storage_outlined),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'מכסת טיוטות (MB)',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                      Text(
                                        '${draftsQuota.toInt()}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: draftsQuota,
                                    min: 50,
                                    max: 100,
                                    divisions: 5,
                                    label: draftsQuota.toInt().toString(),
                                    onChanged: (value) {
                                      setState(() => draftsQuota = value);
                                      Settings.setValue<double>(
                                          'key-editor-drafts-quota', value);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('סגור'),
              ),
            ],
          );
        },
      ),
    );
  }
}
