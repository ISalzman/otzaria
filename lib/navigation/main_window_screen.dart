import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/indexing/bloc/indexing_bloc.dart';
import 'package:otzaria/indexing/bloc/indexing_event.dart';
import 'package:otzaria/indexing/bloc/indexing_state.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/navigation/startup_work_gate.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/empty_library/empty_library_screen.dart';
import 'package:otzaria/empty_library/bloc/empty_library_bloc.dart';
import 'package:otzaria/find_ref/find_ref_dialog.dart';
import 'package:otzaria/search/view/search_dialog.dart';
import 'package:otzaria/library/view/library_browser.dart';
import 'package:otzaria/tabs/reading_screen.dart';
import 'package:otzaria/tools/more_screen.dart';
import 'package:otzaria/navigation/about_dialog.dart';
import 'package:otzaria/shortcuts/keyboard_shortcuts.dart';
import 'dart:async';
import 'package:otzaria/update/my_updat_widget.dart';
import 'package:otzaria/tools/calendar/ulits/calendar_cubit.dart';
import 'package:otzaria/widgets/ad_popup_dialog.dart';
import 'package:window_manager/window_manager.dart';
import 'package:otzaria/main.dart' show appWindowListener;
import 'package:otzaria/navigation/custom_title_bar.dart';
import 'package:otzaria/migration/sync/background_sync_initializer.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';
import 'package:otzaria/library/bloc/library_event.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';
import 'package:otzaria/workspaces/bloc/workspace_state.dart';
import 'package:otzaria/widgets/indexing_status_overlay.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/settings/settings_exports.dart';
import 'package:otzaria/file_sync/file_sync_bloc.dart';
import 'package:otzaria/file_sync/file_sync_event.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:otzaria/widgets/nav_rail_item.dart';

class MainWindowScreen extends StatefulWidget {
  const MainWindowScreen({super.key});

  @override
  MainWindowScreenState createState() => MainWindowScreenState();
}

// Global key for accessing MoreScreen
final GlobalKey<MoreScreenState> moreScreenKey = GlobalKey<MoreScreenState>();
final GlobalKey<State<LibraryBrowser>> libraryBrowserKey =
    GlobalKey<State<LibraryBrowser>>();

class MainWindowScreenState extends State<MainWindowScreen>
    with TickerProviderStateMixin {
  late final PageController pageController;
  late final CalendarCubit _calendarCubit;
  late final SettingsScreenController _settingsScreenController;
  Orientation? _previousOrientation;
  int _currentPageIndex = 0;

  // Keep the pages list as templates; the actual first page (library)
  // will be built dynamically in build() to allow showing the
  // EmptyLibraryScreen inside the library tab while keeping the
  // rest of the application UI available.
  List<Widget> _pages = [];

  // שמירת הדפים כדי שלא ייבנו מחדש
  Widget? _cachedLibraryPage;
  Widget? _cachedReadingPage;
  Widget? _cachedMorePage;
  Widget? _cachedSettingsPage;

  // שמירת BLoC של EmptyLibrary כדי שלא יאבד את המצב
  EmptyLibraryBloc? _emptyLibraryBloc;

  // שמירת מצב הספרייה הקודם כדי לזהות שינויים
  bool? _previousLibraryEmptyState;

  final StartupWorkGate _startupWorkGate = StartupWorkGate();
  bool _hasCheckedAutoIndex = false;
  bool _hasRestoredFullscreen = false;
  bool _hasStartedFileSync = false;
  bool _isSearchOpen = false;
  bool _isFindRefOpen = false;
  late Screen _lastScreen;

  static const _navData = [
    (
      screen: Screen.library,
      icon: FluentIcons.library_24_regular,
      iconFilled: FluentIcons.library_24_filled,
      label: 'ספרייה',
      shortcutKey: 'key-shortcut-open-library-browser',
      shortcutDefault: 'ctrl+l',
    ),
    (
      screen: Screen.find,
      icon: FluentIcons.book_search_24_regular,
      iconFilled: FluentIcons.book_search_24_filled,
      label: 'איתור',
      shortcutKey: 'key-shortcut-open-find-ref',
      shortcutDefault: 'ctrl+o',
    ),
    (
      screen: Screen.reading,
      icon: FluentIcons.book_open_24_regular,
      iconFilled: FluentIcons.book_open_24_filled,
      label: 'עיון',
      shortcutKey: 'key-shortcut-open-reading-screen',
      shortcutDefault: 'ctrl+r',
    ),
    (
      screen: Screen.search,
      icon: FluentIcons.search_24_regular,
      iconFilled: FluentIcons.search_24_filled,
      label: 'חיפוש',
      shortcutKey: 'key-shortcut-open-new-search',
      shortcutDefault: 'ctrl+q',
    ),
    (
      screen: Screen.more,
      icon: FluentIcons.apps_24_regular,
      iconFilled: FluentIcons.apps_24_filled,
      label: 'כלים',
      shortcutKey: 'key-shortcut-open-more',
      shortcutDefault: 'ctrl+m',
    ),
    (
      screen: Screen.settings,
      icon: FluentIcons.settings_24_regular,
      iconFilled: FluentIcons.settings_24_filled,
      label: 'הגדרות',
      shortcutKey: 'key-shortcut-open-settings',
      shortcutDefault: 'ctrl+comma',
    ),
    (
      screen: Screen.about,
      icon: FluentIcons.info_24_regular,
      iconFilled: FluentIcons.info_24_regular,
      label: 'אודות',
      shortcutKey: null,
      shortcutDefault: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _calendarCubit = CalendarCubit();
    _settingsScreenController = SettingsScreenController();
    _lastScreen = context.read<NavigationBloc>().state.currentScreen;
    final initialPage = _pageIndexForScreen(
          context.read<NavigationBloc>().state.currentScreen,
        ) ??
        Screen.library.index;
    _currentPageIndex = initialPage;
    pageController = PageController(initialPage: initialPage);

    // הצגת פופאפ פרסומת אחרי 5 שניות
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdPopupDialog.showIfNeeded(context);
    });

    // Setup fullscreen sync with window manager
    _setupFullscreenSync();

    // NOTE: Background sync is now triggered by LibraryBloc listener
    // (see MultiBlocListener) to avoid DB lock contention during library loading.
  }

  /// Trigger FileSyncBloc to start syncing AFTER the library is loaded.
  /// Runs only once per app session (guard prevents re-triggering on RefreshLibrary).
  void _startFileSync() {
    if (_hasStartedFileSync) return;
    _hasStartedFileSync = true;

    final isAutoSync =
        Settings.getValue<bool>(SettingsRepository.keyAutoSync) ?? true;
    final settingsState = context.read<SettingsBloc>().state;
    if (isAutoSync && settingsState.canUseSoftwareAndBookUpdates) {
      try {
        context.read<FileSyncBloc>().add(const StartSync());
      } catch (e) {
        debugPrint('Could not start file sync: $e');
      }
    }
  }

  /// Initialize background file sync AFTER library is loaded.
  /// This avoids DB lock contention that caused 17s delays.
  void _initializeBackgroundSync() {
    BackgroundSyncInitializer.initializeAfterDelay(
      delaySeconds: 2, // Small delay to let UI settle after library load
      onComplete: (result) {
        if (!mounted) return;
        if (result.addedBooks > 0 ||
            result.updatedBooks > 0 ||
            result.addedLinks > 0) {
          debugPrint('📚 סנכרון קבצים הושלם: ${result.addedBooks} ספרים חדשים, '
              '${result.updatedBooks} עודכנו, ${result.addedLinks} קישורים');

          // Refresh the library browser to show new books
          try {
            context.read<LibraryBloc>().add(RefreshLibrary());
          } catch (e) {
            debugPrint('Could not refresh library: $e');
          }
        }
      },
    );
  }

  void _tryStartDeferredStartupWork() {
    if (!_startupWorkGate.consumeStartPermission()) {
      return;
    }

    _initializeBackgroundSync();
    _startFileSync();
  }

  /// Setup synchronization between window fullscreen state and settings
  void _setupFullscreenSync() {
    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return;
    }

    // Listen for fullscreen changes from the window manager (e.g., user presses F11 in OS)
    appWindowListener?.onFullscreenChanged = (isFullscreen) {
      if (!mounted) return;
      final settingsBloc = context.read<SettingsBloc>();
      // Only update if the state is different to avoid loops
      if (settingsBloc.state.isFullscreen != isFullscreen) {
        settingsBloc.add(UpdateIsFullscreen(isFullscreen));
      }
    };
  }

  /// Restore fullscreen state from settings when app starts
  Future<void> _restoreFullscreenState(BuildContext context) async {
    if (_hasRestoredFullscreen) return;
    _hasRestoredFullscreen = true;

    if (kIsWeb ||
        (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
      return;
    }

    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState.isFullscreen) {
      await windowManager.setFullScreen(true);
    }
  }

  void _checkAndStartIndexing(BuildContext context) {
    // Only check once, after settings are loaded
    if (_hasCheckedAutoIndex) return;
    _hasCheckedAutoIndex = true;

    // Check if auto-update is enabled
    if (context.read<SettingsBloc>().state.autoUpdateIndex) {
      DataRepository.instance.library.then((library) {
        if (!mounted || !context.mounted) return;
        context.read<IndexingBloc>().add(StartIndexing(library));
      });
    }
  }

  @override
  void dispose() {
    // Clean up fullscreen callback
    appWindowListener?.onFullscreenChanged = null;
    _calendarCubit.close();
    _emptyLibraryBloc?.close();
    pageController.dispose();
    super.dispose();
  }

  void _handleOrientationChange(BuildContext context, Orientation orientation) {
    if (_previousOrientation != orientation) {
      _previousOrientation = orientation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final currentScreen =
            context.read<NavigationBloc>().state.currentScreen;
        final targetPage = _pageIndexForScreen(currentScreen);
        if (targetPage == null) {
          return;
        }

        if (_currentPageIndex != targetPage) {
          setState(() {
            _currentPageIndex = targetPage;
          });
          if (pageController.hasClients) {
            pageController.jumpToPage(targetPage);
          }
        }
      });
    }
  }

  /// ודאו שה-PageView מסונכרן למצב הניווט הנוכחי גם אם בחרו שוב באותו יעד.
  Future<void> _syncPageWithState() async {
    if (!mounted || !pageController.hasClients) return;
    final currentScreen = context.read<NavigationBloc>().state.currentScreen;
    final targetPage = _pageIndexForScreen(currentScreen);
    if (targetPage == null) return;
    if (_currentPageIndex == targetPage) return;

    setState(() {
      _currentPageIndex = targetPage;
    });
    pageController.jumpToPage(targetPage);
  }

  List<NavigationDestination> _buildNavigationDestinations() {
    return [
      for (final item in _navData)
        NavigationDestination(
          tooltip: '',
          icon: item.shortcutKey == null
              ? Icon(item.icon)
              : Tooltip(
                  preferBelow: false,
                  message: (Settings.getValue<String>(item.shortcutKey!) ??
                          item.shortcutDefault!)
                      .toUpperCase(),
                  child: Icon(item.icon),
                ),
          selectedIcon: Icon(item.iconFilled),
          label: item.label,
        ),
    ];
  }

  void _handleNavigationChange(
    BuildContext context,
    NavigationState state,
  ) async {
    if (!mounted || !context.mounted) return;

    if (state.currentScreen != _lastScreen) {
      if (_lastScreen == Screen.library) {
        final libraryState = libraryBrowserKey.currentState;
        if (libraryState != null) {
          (libraryState as dynamic).closeTransientPanels();
        }
      } else if (_lastScreen == Screen.more) {
        moreScreenKey.currentState?.closeTransientPanels();
      }
      _lastScreen = state.currentScreen;
    }

    final targetPage = _pageIndexForScreen(state.currentScreen);
    if (targetPage != null && _currentPageIndex != targetPage) {
      setState(() {
        _currentPageIndex = targetPage;
      });
      if (pageController.hasClients) {
        pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    if (state.currentScreen == Screen.library) {
      context.read<FocusRepository>().requestLibrarySearchFocus(
            selectAll: true,
          );
    } else if (state.currentScreen == Screen.more) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<FocusRepository>().requestMoreScreenFocus();
        }
      });
    } else if (state.currentScreen == Screen.reading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<FocusRepository>().requestBookContentFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NavigationBloc, NavigationState>(
          listenWhen: (previous, current) =>
              previous.currentScreen != current.currentScreen,
          listener: _handleNavigationChange,
        ),
        BlocListener<WorkspaceBloc, WorkspaceState>(
          listenWhen: (previous, current) =>
              previous.activeWorkspaceId != current.activeWorkspaceId ||
              (previous.isLoading && !current.isLoading),
          listener: (context, state) {
            // עדכון שם שולחן העבודה הנוכחי ב-HistoryBloc
            final currentId = state.activeWorkspaceId;
            if (currentId != null) {
              final workspace =
                  state.workspaces.firstWhere((w) => w.id == currentId);
              context.read<HistoryBloc>().add(
                    SetCurrentWorkspaceName(workspace.name),
                  );
            }
          },
        ),
        BlocListener<LibraryBloc, LibraryState>(
          listenWhen: (previous, current) =>
              previous.isLoading &&
              !current.isLoading &&
              current.library != null,
          listener: (context, state) {
            _startupWorkGate.markLibraryLoaded();
            _tryStartDeferredStartupWork();
          },
        ),
        BlocListener<IndexingBloc, IndexingState>(
          listenWhen: (previous, current) =>
              (previous is IndexingInProgress) !=
              (current is IndexingInProgress),
          listener: (context, state) {
            _startupWorkGate.markIndexingRunning(
              state is IndexingInProgress,
            );
            _tryStartDeferredStartupWork();
          },
        ),
        BlocListener<SettingsBloc, SettingsState>(
          listenWhen: (previous, current) {
            // Trigger when settings are loaded for the first time (not initial state anymore)
            // or when autoUpdateIndex changes
            final isInitialLoad = previous == SettingsState.initial() &&
                current != SettingsState.initial();
            final hasChanged =
                previous.autoUpdateIndex != current.autoUpdateIndex;
            return isInitialLoad || hasChanged;
          },
          listener: (context, state) {
            // When settings are loaded for the first time, check if we should start indexing
            _checkAndStartIndexing(context);
            _startupWorkGate.markIndexingDecisionResolved(
              expectIndexing: state.autoUpdateIndex,
            );
            _tryStartDeferredStartupWork();
            // Also restore fullscreen state
            _restoreFullscreenState(context);
          },
        ),
      ],
      child: BlocProvider.value(
        value: _calendarCubit,
        child: BlocBuilder<NavigationBloc, NavigationState>(
          builder: (context, state) {
            // Build the pages list here so we can inject the EmptyLibraryScreen
            // into the library page while keeping the rest of the app visible.
            // נבנה את הדפים רק פעם אחת ונשמור אותם
            // אם מצב הספרייה השתנה, נבנה מחדש את דף הספרייה
            if (_cachedLibraryPage == null ||
                state.isLibraryEmpty !=
                    (_cachedLibraryPage is EmptyLibraryScreen) ||
                _previousLibraryEmptyState != state.isLibraryEmpty) {
              if (state.isLibraryEmpty) {
                // יצירת BLoC פעם אחת אם עדיין לא קיים
                _emptyLibraryBloc ??= EmptyLibraryBloc();
                _cachedLibraryPage = EmptyLibraryScreen(
                  bloc: _emptyLibraryBloc,
                  onLibraryLoaded: () {
                    context.read<NavigationBloc>().refreshLibrary();
                  },
                );
              } else {
                // אם הספרייה כבר לא ריקה, נסגור את ה-BLoC
                _emptyLibraryBloc?.close();
                _emptyLibraryBloc = null;
                _cachedLibraryPage = LibraryBrowser(key: libraryBrowserKey);
              }
              _previousLibraryEmptyState = state.isLibraryEmpty;
            }

            _cachedReadingPage ??= const ReadingScreen();
            _cachedMorePage ??= MoreScreen(key: moreScreenKey);
            _cachedSettingsPage ??=
                MySettingsScreen(controller: _settingsScreenController);

            _pages = [
              _cachedLibraryPage!,
              _cachedReadingPage!,
              _cachedMorePage!,
              _cachedSettingsPage!,
            ];

            return SafeArea(
              child: KeyboardShortcuts(
                child: MyUpdatWidget(
                  child: Scaffold(
                    resizeToAvoidBottomInset: false,
                    body: Stack(
                      children: [
                        Column(
                          children: [
                            const CustomTitleBar(),
                            Expanded(
                              child: OrientationBuilder(
                                builder: (context, orientation) {
                                  _handleOrientationChange(
                                      context, orientation);

                                  final pageView = PageView(
                                    controller: pageController,
                                    scrollDirection:
                                        orientation == Orientation.landscape
                                            ? Axis.vertical
                                            : Axis.horizontal,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: _pages,
                                  );

                                  if (orientation == Orientation.landscape) {
                                    return Row(
                                      children: [
                                        ColoredBox(
                                          color: AppSurfaces.panelBackground(
                                            context,
                                          ),
                                          child: SizedBox.fromSize(
                                            size: const Size.fromWidth(74),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: Material(
                                                    color: AppSurfaces
                                                        .panelBackground(
                                                      context,
                                                    ),
                                                    surfaceTintColor:
                                                        Colors.transparent,
                                                    child: LayoutBuilder(
                                                      builder: (context,
                                                          constraints) {
                                                        const buttonHeight =
                                                            60.0;
                                                        final totalButtonsHeight =
                                                            _navData.length *
                                                                buttonHeight;
                                                        final minSpacerHeight =
                                                            20.0;
                                                        final needsScroll =
                                                            totalButtonsHeight +
                                                                    minSpacerHeight >
                                                                constraints
                                                                    .maxHeight;

                                                        if (needsScroll) {
                                                          return SingleChildScrollView(
                                                            child: Column(
                                                              children: [
                                                                for (int i = 0;
                                                                    i <
                                                                        _navData
                                                                            .length;
                                                                    i++)
                                                                  _buildNavRailItem(
                                                                    context,
                                                                    i,
                                                                    state
                                                                        .currentScreen,
                                                                  ),
                                                              ],
                                                            ),
                                                          );
                                                        }

                                                        return Column(
                                                          children: [
                                                            for (int i = 0;
                                                                i < 5;
                                                                i++)
                                                              _buildNavRailItem(
                                                                context,
                                                                i,
                                                                state
                                                                    .currentScreen,
                                                              ),
                                                            const Spacer(),
                                                            for (int i = 5;
                                                                i <
                                                                    _navData
                                                                        .length;
                                                                i++)
                                                              _buildNavRailItem(
                                                                context,
                                                                i,
                                                                state
                                                                    .currentScreen,
                                                              ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const VerticalDivider(
                                            thickness: 1, width: 1),
                                        Expanded(child: pageView),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        Expanded(child: pageView),
                                        NavigationBar(
                                          backgroundColor:
                                              AppSurfaces.panelBackground(
                                            context,
                                          ),
                                          surfaceTintColor: Colors.transparent,
                                          destinations:
                                              _buildNavigationDestinations(),
                                          selectedIndex:
                                              _getActiveNavigationIndex(
                                            state.currentScreen,
                                          ),
                                          onDestinationSelected: (index) async {
                                            await _onNavTap(
                                              context,
                                              index,
                                              state.currentScreen,
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        IndexingStatusOverlay(
                          onTap: _openIndexingSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openIndexingSettings() {
    _settingsScreenController.openTab(SettingsTab.library);
    context.read<NavigationBloc>().add(
          const NavigateToScreen(Screen.settings),
        );
  }

  int? _pageIndexForScreen(Screen screen) {
    switch (screen) {
      case Screen.library:
        return 0;
      case Screen.reading:
      case Screen.search:
        return 1;
      case Screen.more:
        return 2;
      case Screen.settings:
        return 3;
      case Screen.find:
      case Screen.about:
        return null;
    }
  }

  void _handleSearchTabOpen(BuildContext context) {
    if (_isSearchOpen) {
      Navigator.of(context).pop();
      return;
    }

    final navigationBloc = context.read<NavigationBloc>();
    setState(() => _isSearchOpen = true);

    showDialog(
      context: context,
      builder: (context) => const SearchDialog(existingTab: null),
    ).then((_) {
      if (!mounted) return;
      setState(() => _isSearchOpen = false);
      final currentScreen = navigationBloc.state.currentScreen;
      if (currentScreen == Screen.reading || currentScreen == Screen.search) {
        _syncPageWithState();
      }
    });
  }

  void _handleFindRefOpen(BuildContext context) {
    if (_isFindRefOpen) {
      Navigator.of(context).pop();
      return;
    }

    final navigationBloc = context.read<NavigationBloc>();
    setState(() => _isFindRefOpen = true);

    showDialog(
      context: context,
      builder: (context) => FindRefDialog(),
    ).then((_) {
      if (!mounted) return;
      setState(() => _isFindRefOpen = false);
      final currentScreen = navigationBloc.state.currentScreen;
      if (currentScreen == Screen.reading || currentScreen == Screen.search) {
        _syncPageWithState();
      }
    });
  }

  int _getSelectedIndex(Screen currentScreen) {
    // מיפוי מחדש של האינדקסים כיון שהסרנו את דף האיתור
    switch (currentScreen) {
      case Screen.library:
        return 0;
      case Screen.find:
        return -1; // לא נבחר
      case Screen.reading:
        return 2;
      case Screen.search:
        return 3;
      case Screen.more:
        return 4;
      case Screen.settings:
        return 5;
      case Screen.about:
        return 6;
    }
  }

  int _getActiveNavigationIndex(Screen currentScreen) {
    if (_isFindRefOpen) {
      return 1;
    }
    if (_isSearchOpen) {
      return 3;
    }
    return _getSelectedIndex(currentScreen);
  }

  Future<void> _onNavTap(
    BuildContext context,
    int index,
    Screen currentScreen,
  ) async {
    final currentIndex = _getSelectedIndex(currentScreen);
    final item = _navData[index];
    if (index == currentIndex &&
        item.screen != Screen.search &&
        item.screen != Screen.find &&
        item.screen != Screen.about) {
      await _syncPageWithState();
      return;
    }

    if (item.screen == Screen.search) {
      _handleSearchTabOpen(context);
    } else if (item.screen == Screen.find) {
      _handleFindRefOpen(context);
    } else if (item.screen == Screen.about) {
      showDialog(
        context: context,
        builder: (context) => const AboutDialogWidget(),
      );
    } else {
      context.read<NavigationBloc>().add(
            NavigateToScreen(item.screen),
          );
    }

    if (item.screen == Screen.library) {
      context.read<FocusRepository>().requestLibrarySearchFocus(
            selectAll: true,
          );
    }
  }

  Widget _buildNavRailItem(
    BuildContext context,
    int index,
    Screen currentScreen,
  ) {
    final item = _navData[index];
    final isSelected = _getActiveNavigationIndex(currentScreen) == index;
    final tooltip = item.shortcutKey == null
        ? null
        : (Settings.getValue<String>(item.shortcutKey!) ??
                item.shortcutDefault!)
            .toUpperCase();

    return NavRailItem(
      icon: item.icon,
      iconFilled: item.iconFilled,
      label: item.label,
      isSelected: isSelected,
      onTap: () => _onNavTap(context, index, currentScreen),
      tooltip: tooltip,
    );
  }
}

class KeepAlivePage extends StatefulWidget {
  final Widget child;

  const KeepAlivePage({super.key, required this.child});

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
