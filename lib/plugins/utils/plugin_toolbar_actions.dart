import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';
import 'package:otzaria/plugins/models/plugin_toolbar_item.dart';
import 'package:otzaria/plugins/services/plugin_page_launcher.dart';
import 'package:otzaria/plugins/services/plugin_runtime_dispatcher.dart';
import 'package:otzaria/plugins/utils/fluent_icon_resolver.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';
import 'package:otzaria/widgets/navigation/responsive_action_bar.dart';

typedef PluginHostActionDispatcher =
    Future<void> Function(String pluginId, CompiledDeclarativeAction action);

/// בונה את פקדי התוספים לשורת הפקדים של מסך העיון.
///
/// [context] — 'reader-text' או 'reader-pdf'.
/// [placement] — 'primary' לפקדים בשורה עצמה, 'overflow' לפקדים שהתוסף
/// ביקש להציג רק בתפריט "עוד פעולות" (המסך מזרים אותם ל-alwaysInMenu).
/// [locationPayload] — נפתר בזמן הלחיצה, כדי שהאירוע ישקף את המיקום העדכני.
List<ActionButtonData> buildPluginToolbarActions({
  required List<(String pluginId, PluginToolbarItem item)> records,
  required String context,
  required bool compact,
  required Future<Map<String, dynamic>> Function() locationPayload,
  String placement = 'primary',
  PluginRuntimeDispatcher? dispatcher,
  PluginHostActionDispatcher? hostActionDispatcher,
}) {
  final runtime = dispatcher ?? PluginRuntimeDispatcher.instance;
  return [
    for (final record in records)
      if (record.$2.contexts.contains(context) &&
          record.$2.placement == placement)
        _buildAction(
          pluginId: record.$1,
          item: record.$2,
          context: context,
          compact: compact,
          locationPayload: locationPayload,
          dispatcher: runtime,
          hostActionDispatcher: hostActionDispatcher,
        ),
  ];
}

ActionButtonData _buildAction({
  required String pluginId,
  required PluginToolbarItem item,
  required String context,
  required bool compact,
  required Future<Map<String, dynamic>> Function() locationPayload,
  required PluginRuntimeDispatcher dispatcher,
  required PluginHostActionDispatcher? hostActionDispatcher,
}) {
  final icon =
      fluentIconFromName(item.icon) ?? FluentIcons.puzzle_piece_24_regular;
  if (item.type == 'menu' || item.type == 'split') {
    final visibleChildren = [
      for (final child in item.children)
        if (child.contexts.contains(context)) child,
    ];
    void dispatchChild(String childId) {
      final child = visibleChildren.where((c) => c.id == childId).firstOrNull;
      if (child == null) return;
      _dispatchItemClick(
        dispatcher: dispatcher,
        pluginId: pluginId,
        item: child,
        context: context,
        locationPayload: locationPayload,
        hostActionDispatcher: hostActionDispatcher,
      );
    }

    final childActions = [
      for (final child in visibleChildren)
        ActionButtonData(
          widget: const SizedBox.shrink(),
          icon: fluentIconFromName(child.icon),
          tooltip: child.title,
          onPressed: () => dispatchChild(child.id),
        ),
    ];

    if (item.type == 'split') {
      return ActionButtonData.split(
        icon: icon,
        tooltip: item.title,
        compact: compact,
        menuItems: childActions,
        onPressed: () => _dispatchItemClick(
          dispatcher: dispatcher,
          pluginId: pluginId,
          item: item,
          context: context,
          locationPayload: locationPayload,
          hostActionDispatcher: hostActionDispatcher,
        ),
      );
    }

    return ActionButtonData(
      widget: AppPopupMenuButton<String>(
        iconData: icon,
        tooltip: item.title,
        entries: [
          for (final child in visibleChildren)
            AppMenuEntry(
              value: child.id,
              label: child.title,
              icon: fluentIconFromName(child.icon),
            ),
        ],
        onSelected: dispatchChild,
      ),
      icon: icon,
      tooltip: item.title,
      // ב-overflow הפקד עצמו לא בנוי בעץ, לכן הילדים מוצגים כתת-תפריט
      submenuItems: childActions,
    );
  }
  return ActionButtonData.simple(
    icon: icon,
    tooltip: item.title,
    compact: compact,
    onPressed: () => _dispatchItemClick(
      dispatcher: dispatcher,
      pluginId: pluginId,
      item: item,
      context: context,
      locationPayload: locationPayload,
      hostActionDispatcher: hostActionDispatcher,
    ),
  );
}

Future<void> _dispatchItemClick({
  required PluginRuntimeDispatcher dispatcher,
  required String pluginId,
  required PluginToolbarItem item,
  required String context,
  required Future<Map<String, dynamic>> Function() locationPayload,
  required PluginHostActionDispatcher? hostActionDispatcher,
}) async {
  final hostAction = item.hostAction;
  if (hostAction != null) {
    await hostActionDispatcher?.call(pluginId, hostAction);
    return;
  }
  final payload = <String, dynamic>{
    'itemId': item.id,
    'context': context,
    ...await locationPayload(),
    'param': item.param,
  };
  final topic = item.onClickEvent ?? 'reader.toolbar_item_clicked';
  if (item.openPlugin) {
    PluginPageLauncher.instance.open(pluginId, topic: topic, payload: payload);
    return;
  }
  await dispatcher.dispatchEventToPlugin(
    pluginId,
    topic,
    payload,
    preferBackground: true,
  );
}
