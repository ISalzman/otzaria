import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:otzaria/focus/focus_repository.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/tabs/models/searching_tab.dart';
import 'package:otzaria/find_ref/find_ref_dialog.dart';
import 'package:otzaria/search/view/search_dialog.dart';
import 'package:otzaria/bookmarks/bookmarks_dialog.dart';
import 'package:otzaria/history/history_dialog.dart';
import 'package:otzaria/workspaces/view/workspace_switcher_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:otzaria/settings/settings_event.dart';

class KeyboardShortcuts extends StatefulWidget {
  final Widget child;

  const KeyboardShortcuts({super.key, required this.child});

  @override
  State<KeyboardShortcuts> createState() => _KeyboardShortcutsState();
}

class _KeyboardShortcutsState extends State<KeyboardShortcuts> {
  /// בודק אם הקיצור שנלחץ תואם להגדרה
  bool _matchesShortcut(KeyEvent event, String shortcutSetting) {
    if (event is! KeyDownEvent) return false;

    final parts = shortcutSetting.toLowerCase().split('+');
    final requiresCtrl = parts.contains('ctrl') || parts.contains('control');
    final requiresShift = parts.contains('shift');
    final requiresAlt = parts.contains('alt');

    // בדיקת modifiers
    if (requiresCtrl != HardwareKeyboard.instance.isControlPressed) return false;
    if (requiresShift != HardwareKeyboard.instance.isShiftPressed) return false;
    if (requiresAlt != HardwareKeyboard.instance.isAltPressed) return false;

    // מציאת המקש הראשי (לא modifier)
    final mainKey = parts
        .where((p) =>
            p != 'ctrl' &&
            p != 'control' &&
            p != 'shift' &&
            p != 'alt' &&
            p != 'meta')
        .firstOrNull;

    if (mainKey == null) return false;

    // מיפוי שם המקש ל-LogicalKeyboardKey
    final pressedKeyLabel = event.logicalKey.keyLabel.toLowerCase();

    // בדיקת אותיות
    if (mainKey.length == 1 &&
        mainKey.codeUnitAt(0) >= 97 &&
        mainKey.codeUnitAt(0) <= 122) {
      return pressedKeyLabel == mainKey;
    }

    // בדיקת מספרים
    if (mainKey.length == 1 &&
        mainKey.codeUnitAt(0) >= 48 &&
        mainKey.codeUnitAt(0) <= 57) {
      return event.logicalKey == _digitKeyFromChar(mainKey);
    }

    // בדיקת מקשים מיוחדים
    return _matchesSpecialKey(event.logicalKey, mainKey);
  }

  LogicalKeyboardKey? _digitKeyFromChar(String digit) {
    switch (digit) {
      case '0':
        return LogicalKeyboardKey.digit0;
      case '1':
        return LogicalKeyboardKey.digit1;
      case '2':
        return LogicalKeyboardKey.digit2;
      case '3':
        return LogicalKeyboardKey.digit3;
      case '4':
        return LogicalKeyboardKey.digit4;
      case '5':
        return LogicalKeyboardKey.digit5;
      case '6':
        return LogicalKeyboardKey.digit6;
      case '7':
        return LogicalKeyboardKey.digit7;
      case '8':
        return LogicalKeyboardKey.digit8;
      case '9':
        return LogicalKeyboardKey.digit9;
      default:
        return null;
    }
  }

  bool _matchesSpecialKey(LogicalKeyboardKey key, String keyName) {
    switch (keyName) {
      case 'comma':
        return key == LogicalKeyboardKey.comma;
      case 'period':
        return key == LogicalKeyboardKey.period;
      case 'slash':
        return key == LogicalKeyboardKey.slash;
      case 'semicolon':
        return key == LogicalKeyboardKey.semicolon;
      case 'tab':
        return key == LogicalKeyboardKey.tab;
      case 'escape':
        return key == LogicalKeyboardKey.escape;
      case 'f1':
        return key == LogicalKeyboardKey.f1;
      case 'f2':
        return key == LogicalKeyboardKey.f2;
      case 'f3':
        return key == LogicalKeyboardKey.f3;
      case 'f4':
        return key == LogicalKeyboardKey.f4;
      case 'f5':
        return key == LogicalKeyboardKey.f5;
      case 'f6':
        return key == LogicalKeyboardKey.f6;
      case 'f7':
        return key == LogicalKeyboardKey.f7;
      case 'f8':
        return key == LogicalKeyboardKey.f8;
      case 'f9':
        return key == LogicalKeyboardKey.f9;
      case 'f10':
        return key == LogicalKeyboardKey.f10;
      case 'f11':
        return key == LogicalKeyboardKey.f11;
      case 'f12':
        return key == LogicalKeyboardKey.f12;
      default:
        return false;
    }
  }


  /// מטפל באירועי מקלדת ברמה הגלובלית - עובד גם כשיש TextField עם focus
  KeyEventResult _handleKeyEvent(
      FocusNode node, KeyEvent event, Map<String, String> shortcutSettings) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // קריאת ערכי הקיצורים מההגדרות
    final libraryShortcut =
        shortcutSettings['key-shortcut-open-library-browser'] ?? 'ctrl+l';
    final findRefShortcut =
        shortcutSettings['key-shortcut-open-find-ref'] ?? 'ctrl+o';
    final closeTabShortcut =
        shortcutSettings['key-shortcut-close-tab'] ?? 'ctrl+w';
    final closeAllTabsShortcut =
        shortcutSettings['key-shortcut-close-all-tabs'] ?? 'ctrl+shift+w';
    final readingScreenShortcut =
        shortcutSettings['key-shortcut-open-reading-screen'] ?? 'ctrl+r';
    final newSearchShortcut =
        shortcutSettings['key-shortcut-open-new-search'] ?? 'ctrl+q';
    final settingsShortcut =
        shortcutSettings['key-shortcut-open-settings'] ?? 'ctrl+comma';
    final moreShortcut =
        shortcutSettings['key-shortcut-open-more'] ?? 'ctrl+m';
    final bookmarksShortcut =
        shortcutSettings['key-shortcut-open-bookmarks'] ?? 'ctrl+shift+b';
    final historyShortcut =
        shortcutSettings['key-shortcut-open-history'] ?? 'ctrl+h';
    final workspaceShortcut =
        shortcutSettings['key-shortcut-switch-workspace'] ?? 'ctrl+k';

    // ספרייה
    if (_matchesShortcut(event, libraryShortcut)) {
      context.read<NavigationBloc>().add(const NavigateToScreen(Screen.library));
      context.read<FocusRepository>().requestLibrarySearchFocus(selectAll: true);
      return KeyEventResult.handled;
    }

    // איתור
    if (_matchesShortcut(event, findRefShortcut)) {
      showDialog(context: context, builder: (context) => FindRefDialog());
      return KeyEventResult.handled;
    }

    // סגור טאב
    if (_matchesShortcut(event, closeTabShortcut)) {
      final tabsBloc = context.read<TabsBloc>();
      final historyBloc = context.read<HistoryBloc>();
      if (tabsBloc.state.tabs.isNotEmpty) {
        final currentTab = tabsBloc.state.tabs[tabsBloc.state.currentTabIndex];
        historyBloc.add(AddHistory(currentTab));
      }
      tabsBloc.add(const CloseCurrentTab());
      return KeyEventResult.handled;
    }

    // סגור כל הטאבים
    if (_matchesShortcut(event, closeAllTabsShortcut)) {
      final tabsBloc = context.read<TabsBloc>();
      final historyBloc = context.read<HistoryBloc>();
      for (final tab in tabsBloc.state.tabs) {
        if (tab is! SearchingTab) {
          historyBloc.add(AddHistory(tab));
        }
      }
      tabsBloc.add(CloseAllTabs());
      return KeyEventResult.handled;
    }

    // עיון
    if (_matchesShortcut(event, readingScreenShortcut)) {
      context.read<NavigationBloc>().add(const NavigateToScreen(Screen.reading));
      return KeyEventResult.handled;
    }

    // חיפוש חדש
    if (_matchesShortcut(event, newSearchShortcut)) {
      final useFastSearch = context.read<SettingsBloc>().state.useFastSearch;
      if (!useFastSearch) {
        _openLegacySearchTab(context);
      } else {
        showDialog(
          context: context,
          builder: (context) => const SearchDialog(existingTab: null),
        );
      }
      return KeyEventResult.handled;
    }

    // הגדרות
    if (_matchesShortcut(event, settingsShortcut)) {
      context.read<NavigationBloc>().add(const NavigateToScreen(Screen.settings));
      return KeyEventResult.handled;
    }

    // כלים
    if (_matchesShortcut(event, moreShortcut)) {
      context.read<NavigationBloc>().add(const NavigateToScreen(Screen.more));
      return KeyEventResult.handled;
    }

    // סימניות
    if (_matchesShortcut(event, bookmarksShortcut)) {
      showDialog(
        context: context,
        builder: (context) => const BookmarksDialog(),
      );
      return KeyEventResult.handled;
    }

    // היסטוריה
    if (_matchesShortcut(event, historyShortcut)) {
      showDialog(
        context: context,
        builder: (context) => const HistoryDialog(),
      );
      return KeyEventResult.handled;
    }

    // החלף שולחן עבודה
    if (_matchesShortcut(event, workspaceShortcut)) {
      showDialog(
        context: context,
        builder: (context) => const WorkspaceSwitcherDialog(),
      );
      return KeyEventResult.handled;
    }

    // Ctrl+Tab - טאב הבא
    if (_matchesShortcut(event, 'ctrl+tab')) {
      context.read<TabsBloc>().add(NavigateToNextTab());
      return KeyEventResult.handled;
    }

    // Ctrl+Shift+Tab - טאב קודם
    if (_matchesShortcut(event, 'ctrl+shift+tab')) {
      context.read<TabsBloc>().add(NavigateToPreviousTab());
      return KeyEventResult.handled;
    }

    // F11 - מסך מלא
    if (_matchesShortcut(event, 'f11')) {
      final settingsBloc = context.read<SettingsBloc>();
      final newFullscreenState = !settingsBloc.state.isFullscreen;
      settingsBloc.add(UpdateIsFullscreen(newFullscreenState));
      if (newFullscreenState) {
        windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      }
      windowManager.setFullScreen(newFullscreenState);
      if (!newFullscreenState) {
        windowManager.setTitleBarStyle(TitleBarStyle.normal);
      }
      return KeyEventResult.handled;
    }

    // ESC - יציאה ממסך מלא
    if (_matchesShortcut(event, 'escape')) {
      final settingsBloc = context.read<SettingsBloc>();
      if (settingsBloc.state.isFullscreen) {
        settingsBloc.add(const UpdateIsFullscreen(false));
        windowManager.setFullScreen(false);
        windowManager.setTitleBarStyle(TitleBarStyle.normal);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (previous, current) => previous.shortcuts != current.shortcuts,
      builder: (context, state) {
        // משתמשים ב-FocusScope עם onKeyEvent כדי לתפוס קיצורים גם כשיש TextField עם focus
        return FocusScope(
          autofocus: true,
          onKeyEvent: (node, event) =>
              _handleKeyEvent(node, event, state.shortcuts),
          child: widget.child,
        );
      },
    );
  }

  void _openLegacySearchTab(BuildContext context) {
    final tabsBloc = context.read<TabsBloc>();
    final navigationBloc = context.read<NavigationBloc>();

    final tabsState = tabsBloc.state;
    final hasSearchTab = tabsState.tabs.any(
      (tab) => tab.runtimeType == SearchingTab,
    );

    if (!hasSearchTab) {
      tabsBloc.add(AddTab(SearchingTab("חיפוש", "")));
    } else {
      final currentScreen = navigationBloc.state.currentScreen;
      final isAlreadySearchTab = currentScreen == Screen.search &&
          tabsState.tabs[tabsState.currentTabIndex].runtimeType == SearchingTab;
      if (!isAlreadySearchTab) {
        final searchTabIndex = tabsState.tabs.indexWhere(
          (tab) => tab.runtimeType == SearchingTab,
        );
        if (searchTabIndex != -1) {
          tabsBloc.add(SetCurrentTab(searchTabIndex));
        }
      }
    }

    navigationBloc.add(const NavigateToScreen(Screen.search));
  }
}
