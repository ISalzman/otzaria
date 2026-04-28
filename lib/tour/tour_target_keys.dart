import 'package:flutter/widgets.dart';

final List<GlobalKey> tourMainNavigationTargetKeys = List<GlobalKey>.generate(
  6,
  (index) => GlobalKey(debugLabel: 'tour_main_navigation_$index'),
);

final GlobalKey tourReadingScreenTargetKey = GlobalKey(
  debugLabel: 'tour_reading_screen_target',
);
final GlobalKey tourReadingTabsTargetKey = GlobalKey(
  debugLabel: 'tour_reading_tabs_target',
);
final GlobalKey tourReadingSettingsButtonTargetKey = GlobalKey(
  debugLabel: 'tour_reading_settings_button_target',
);
final GlobalKey tourTabContextMenuTargetKey = GlobalKey(
  debugLabel: 'tour_tab_context_menu_target',
);
final GlobalKey tourTabSideBySideMenuItemTargetKey = GlobalKey(
  debugLabel: 'tour_tab_side_by_side_menu_item_target',
);

final GlobalKey tourFindRefDialogTargetKey = GlobalKey(
  debugLabel: 'tour_find_ref_dialog_target',
);

final GlobalKey tourSearchDialogTargetKey = GlobalKey(
  debugLabel: 'tour_search_dialog_target',
);

final Map<String, GlobalKey> tourToolTabTargetKeys = {
  'builtin.calendar': GlobalKey(debugLabel: 'tour_tool_calendar_tab_target'),
  'builtin.gematria': GlobalKey(debugLabel: 'tour_tool_gematria_tab_target'),
  'builtin.notes': GlobalKey(debugLabel: 'tour_tool_notes_tab_target'),
};

final Map<int, GlobalKey> tourSettingsTabTargetKeys = {
  0: GlobalKey(debugLabel: 'tour_settings_design_tab_target'),
  4: GlobalKey(debugLabel: 'tour_settings_shortcuts_tab_target'),
  5: GlobalKey(debugLabel: 'tour_settings_system_tab_target'),
};

final GlobalKey tourBackupSettingsTargetKey = GlobalKey(
  debugLabel: 'tour_backup_settings_target',
);
final GlobalKey tourShortcutsSettingsTargetKey = GlobalKey(
  debugLabel: 'tour_shortcuts_settings_target',
);
