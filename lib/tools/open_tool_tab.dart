import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/messages/library_messages.dart';
import 'package:otzaria/core/messages/tools_messages.dart';
import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';
import 'package:otzaria/tools/tool_catalog_entry.dart';

/// פותח כלי ככרטיסיה במסך העיון.
///
/// תוסף קיים ממוקד, כי הוא מוגבל למופע WebView יחיד; כלים מובנים יכולים
/// להיפתח במספר כרטיסיות.
void openToolTab(BuildContext context, ToolCatalogEntry entry) {
  context.read<TabsBloc>().add(
    OpenOrFocusTab(ToolTab(toolId: entry.toolId, title: entry.label)),
  );
  context.read<NavigationBloc>().add(
    const NavigateToScreen(Screen.reading),
  );
}

/// פותח כלי לפי מזהה בלבד — לקישורים עמוקים, קיצורי מקלדת ופריטים מוצמדים
/// לסרגל הניווט.
///
/// כשמערכת התוספים עדיין נטענת הכרטיסיה נפתחת אופטימיסטית עם כותרת גיבוי;
/// `ToolTabScreen` מציג טעינה עד שהמצב האמיתי ידוע. בכל סיבת אי-זמינות אחרת
/// מוצגת הודעה מפורשת במקום שתיקה.
void openToolTabById(BuildContext context, String toolId) {
  final settingsState = context.read<SettingsBloc>().state;
  final result = lookupTool(
    toolId,
    hiddenBuiltInToolIds: settingsState.hiddenBuiltInToolIds,
    isOfflineMode: settingsState.isOfflineMode,
    pluginState: context.read<PluginSystemBloc>().state,
  );

  switch (result) {
    case ToolAvailable(:final entry):
      openToolTab(context, entry);
    case ToolUnavailable(reason: ToolUnavailableReason.loading):
      context.read<TabsBloc>().add(
        OpenOrFocusTab(
          ToolTab(toolId: toolId, title: ToolTab.fallbackTitleFor(toolId)),
        ),
      );
      context.read<NavigationBloc>().add(
        const NavigateToScreen(Screen.reading),
      );
    case ToolUnavailable(:final reason, :final name):
      UiSnack.showError(toolUnavailableMessage(reason, name, toolId));
  }
}

/// הכרטיסיות הפתוחות של תוספים שכבר אינם מותקנים.
///
/// מחיקת תוסף חייבת לסגור את הכרטיסיה שלו — אחרת נשארת כרטיסיה עם "הכלי אינו
/// זמין" שהמשתמש צריך לסגור ידנית. תוסף מושבת או מוסתר מהכלים אינו נכלל כאן:
/// הוא עדיין מותקן והמשתמש יכול להחזירו מההגדרות, ולכן ההודעה בכרטיסיה היא
/// המשוב הנכון.
List<ToolTab> orphanedPluginToolTabs(
  List<OpenedTab> tabs,
  Iterable<String> installedPluginIds,
) {
  final installed = installedPluginIds.toSet();
  return tabs
      .whereType<ToolTab>()
      .where((tab) => tab.isPlugin && !installed.contains(tab.toolId))
      .toList();
}

/// סוגר כרטיסיות של תוספים שהוסרו. נקרא בכל `PluginSystemLoaded`, כי הסרה
/// יכולה להגיע מחלונית התוספים, ממסך ההגדרות או מניהול הכלים.
void closeUninstalledPluginTabs(
  BuildContext context,
  List<InstalledPlugin> installedPlugins,
) {
  final tabsBloc = context.read<TabsBloc>();
  final orphaned = orphanedPluginToolTabs(
    tabsBloc.state.tabs,
    installedPlugins.map((p) => p.pluginId),
  );
  for (final tab in orphaned) {
    tabsBloc.add(RemoveTab(tab));
  }
}

/// הודעת השגיאה המתאימה לסיבת אי-הזמינות.
String toolUnavailableMessage(
  ToolUnavailableReason reason,
  String? name,
  String toolId,
) {
  return switch (reason) {
    ToolUnavailableReason.builtInHidden => ToolsMessages.builtInToolHidden(
      name ?? toolId,
    ),
    ToolUnavailableReason.pluginDisabled => LibraryMessages.pluginDisabled(
      name ?? toolId,
    ),
    ToolUnavailableReason.pluginHiddenFromTools =>
      ToolsMessages.pluginNotShownInTools(name ?? toolId),
    ToolUnavailableReason.pluginRequiresInternet =>
      ToolsMessages.pluginRequiresInternet(name ?? toolId),
    _ => ToolsMessages.toolNotFound(toolId),
  };
}
