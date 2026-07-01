import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/plugins/utils/fluent_icon_resolver.dart';
import 'package:otzaria/plugins/view/plugin_settings_screen.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/settings/search/settings_search_models.dart';
import 'package:otzaria/settings/search/settings_search_registry.dart';
import 'package:otzaria/settings/widgets/settings_widgets_exports.dart';
import 'package:otzaria/settings/view/settings_screen.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/tools/built_in_tools_catalog.dart';
import 'package:otzaria/widgets/misc/animated_pin_button.dart';
import 'package:otzaria/widgets/misc/rtl_icon.dart';
import 'package:otzaria/widgets/widgets_exports.dart';

const String _networkAccessPermission = 'network.access';
const String _networkLocalhostPermission = 'network.localhost';

/// הרשאות הרשת שפעולת ה-bulk "גישה לרשת" מעניקה/מבטלת לפי הצהרת התוסף.
const List<String> _networkPermissions = [
  _networkAccessPermission,
  _networkLocalhostPermission,
];

/// פאנל ניהול כלים (מובנים + תוספים) במסך "הגדרות › כלים".
///
/// מבנה:
/// - כלים מובנים — שורה מתקפלת; לכל שורה הסתרה/הצגה והצמדה לסרגל הניווט.
/// - תוספים מותקנים — בחירה מרובה עם סרגל פעולות (הסתרה, הצמדה, השבתה, הרשאות, מחיקה).
class ToolsManagementPanel extends StatefulWidget {
  const ToolsManagementPanel({super.key});

  /// פריטי חיפוש בהגדרות. נסרק על-ידי tool/generate_search_index.dart.
  static const List<SettingsSearchEntry> searchEntries = [
    SettingsSearchEntry(
      id: 'tools.management.hide',
      title: 'הסתרת כלים',
      subtitle: 'הסתר כלים מובנים או תוספים מהממשק',
      tab: SettingsTab.tools,
      cardId: 'tools.management',
      keywords: ['הסתר', 'הסתרה', 'הסתרת', 'הצג', 'מוסתר', 'כלים', 'תוספים'],
    ),
    SettingsSearchEntry(
      id: 'tools.management.pin_nav_rail',
      title: 'הצמדה לסרגל הניווט',
      subtitle: 'הצמד כלים או תוספים לסרגל הניווט הראשי',
      tab: SettingsTab.tools,
      cardId: 'tools.management',
      keywords: ['הצמד', 'הצמדה', 'ניווט', 'סרגל', 'nav rail'],
    ),
    SettingsSearchEntry(
      id: 'tools.management.plugins',
      title: 'ניהול תוספים',
      subtitle: 'השבתה, הפעלה, מחיקה והרשאות לתוספים',
      tab: SettingsTab.tools,
      cardId: 'tools.plugins',
      keywords: [
        'תוסף',
        'תוספים',
        'מחק',
        'מחיקה',
        'השבת',
        'השבתה',
        'הפעל',
        'הרשאות',
        'רשת',
        'אינטרנט',
        'טעינה אוטומטית',
        'בעלייה'
      ],
    ),
  ];

  @override
  State<ToolsManagementPanel> createState() => _ToolsManagementPanelState();
}

/// מזהי העוגנים של שני האזורים — משמשים גם לחיפוש (SettingsAnchor + searchEntries)
/// וגם להרחבה אוטומטית בניווט מחיפוש.
const String _builtInCardId = 'tools.management';
const String _pluginsCardId = 'tools.plugins';

class _ToolsManagementPanelState extends State<ToolsManagementPanel> {
  /// מזהי התוספים שנבחרו כרגע (בחירה מרובה — תוספים בלבד).
  final Set<String> _selectedIds = <String>{};

  /// האם מצב הבחירה הרב-שורתית פעיל.
  bool _isSelectionMode = false;

  /// מפתחות גלובליים לעטיפות האנימציה — מאפשרים לקרוא ל-playAnimation ישירות.
  final Map<String, GlobalKey<_AnimatedPluginMoveWrapperState>>
      _moveWrapperKeys = {};

  /// מצב פתיחה/סגירה של אזור הכלים המובנים — סגור כברירת מחדל.
  bool _builtInExpanded = false;

  // הרחבה אוטומטית בניווט מחיפוש לכלים המובנים.
  late final ValueListenable<bool> _builtInFlash;

  @override
  void initState() {
    super.initState();
    final registry = SettingsSearchRegistry.instance;
    _builtInFlash = registry.flashNotifierFor(_builtInCardId);
    _builtInFlash.addListener(_onBuiltInFlash);
  }

  @override
  void dispose() {
    _builtInFlash.removeListener(_onBuiltInFlash);
    super.dispose();
  }

  void _onBuiltInFlash() {
    if (_builtInFlash.value && !_builtInExpanded && mounted) {
      setState(() => _builtInExpanded = true);
    }
  }

  void _toggleSelection(String id, bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _enterSelectionMode() {
    setState(() => _isSelectionMode = true);
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllPlugins(List<InstalledPlugin> plugins) {
    setState(() => _selectedIds.addAll(plugins.map((p) => p.pluginId)));
  }

  // ── פעולות כלי מובנה (לחצן בשורה) ───────────────────────────────────────────

  void _toggleBuiltInHide(String toolId, SettingsState state) {
    final next = Set<String>.from(state.hiddenBuiltInToolIds);
    if (!next.add(toolId)) next.remove(toolId);
    context.read<SettingsBloc>().add(UpdateHiddenBuiltInToolIds(next));
  }

  void _toggleBuiltInPin(String toolId, SettingsState state) {
    final next = Set<String>.from(state.builtInToolsPinnedToNavRail);
    if (!next.add(toolId)) next.remove(toolId);
    context.read<SettingsBloc>().add(UpdateBuiltInToolsPinnedToNavRail(next));
  }

  // ── פעולות תוסף בודד (לחצן בשורה) ───────────────────────────────────────────

  void _togglePluginHide(InstalledPlugin plugin) {
    context.read<PluginSystemBloc>().add(SetPluginShowInToolsRequested(
          pluginId: plugin.pluginId,
          showInTools: !plugin.showInTools,
        ));
  }

  void _togglePluginPinNavRail(InstalledPlugin plugin) {
    final bloc = context.read<PluginSystemBloc>();
    if (plugin.pinnedToNavRail) {
      bloc.add(UnpinPluginFromNavRailRequested(plugin.pluginId));
    } else {
      bloc.add(PinPluginToNavRailRequested(plugin.pluginId));
    }
  }

  void _togglePluginEnabled(InstalledPlugin plugin) {
    final bloc = context.read<PluginSystemBloc>();
    if (plugin.enabled) {
      bloc.add(DisablePluginRequested(plugin.pluginId));
    } else {
      bloc.add(EnablePluginRequested(plugin.pluginId));
    }
  }

  Future<void> _deletePlugin(InstalledPlugin plugin) async {
    await showDeletePluginDialog(context, plugin);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PluginSystemBloc, PluginSystemState>(
      builder: (context, pluginState) {
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final plugins = pluginState is PluginSystemLoaded
                ? pluginState.plugins
                : const <InstalledPlugin>[];
            _pruneStaleSelection(plugins);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SettingsCard(
                  cardId: _builtInCardId,
                  title: 'כלים מובנים',
                  children: [
                    ExpandableSection(
                      icon: FluentIcons.apps_24_regular,
                      title: const Text('רשימת הכלים'),
                      subtitle: const Text(
                          'הסתר כלים מהממשק או הצמד אותם לסרגל הניווט הראשי.'),
                      isExpanded: _builtInExpanded,
                      onTap: () =>
                          setState(() => _builtInExpanded = !_builtInExpanded),
                      children: _builtInToolRows(settingsState),
                    ),
                  ],
                ),
                if (plugins.isNotEmpty) ...[
                  kSettingsCardSpacing,
                  SettingsCard(
                    cardId: _pluginsCardId,
                    title: 'תוספים מותקנים',
                    children: [
                      // כותרת + סרגל פעולות כילד אחד כדי ש-divider יופיע רק בין הכותרת לשורות.
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsActionTile.text(
                            icon: FluentIcons.puzzle_piece_24_regular,
                            title: 'רשימת התוספים',
                            subtitle: _isSelectionMode
                                ? '${_selectedIds.length} נבחרו'
                                : 'נהל את התוספים שלך: השבתה, הסתרה, הצמדה, הרשאות ומחיקה. גרור לשינוי סדר.',
                            // LayoutBuilder + Tooltip(OverlayPortal) reactivation
                            // during drag reorder crashes here.
                            responsiveActions: false,
                            actions: _isSelectionMode
                                ? [
                                    ActionButton.ghost(
                                      icon: FluentIcons
                                          .checkbox_checked_24_regular,
                                      text: 'בחר הכל',
                                      onPressed: _selectedIds.length ==
                                              plugins.length
                                          ? null
                                          : () => _selectAllPlugins(plugins),
                                    ),
                                    ActionButton.neutral(
                                      icon:
                                          FluentIcons.dismiss_circle_24_regular,
                                      text: 'ביטול',
                                      onPressed: _exitSelectionMode,
                                    ),
                                  ]
                                : [
                                    ActionButton.neutral(
                                      icon: FluentIcons
                                          .multiselect_rtl_24_regular,
                                      text: 'בחירה',
                                      onPressed: _enterSelectionMode,
                                    ),
                                  ],
                          ),
                          AnimatedSize(
                            duration: AppTokens.animNormal,
                            curve: Curves.easeInOut,
                            child: _isSelectionMode
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Builder(
                                        builder: (ctx) =>
                                            AppCard.sectionDivider(ctx),
                                      ),
                                      _ActionBar(
                                        selectedIds: _selectedIds.toSet(),
                                        plugins: plugins,
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      ..._pluginRows(plugins),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _builtInToolRows(SettingsState state) {
    return [
      for (final meta in kBuiltInToolsCatalog)
        _BuiltInToolRow(
          meta: meta,
          hidden: state.hiddenBuiltInToolIds.contains(meta.toolId),
          pinnedToNavRail:
              state.builtInToolsPinnedToNavRail.contains(meta.toolId),
          onToggleHide: () => _toggleBuiltInHide(meta.toolId, state),
          onTogglePin: () => _toggleBuiltInPin(meta.toolId, state),
        ),
    ];
  }

  List<Widget> _pluginRows(List<InstalledPlugin> plugins) {
    return [
      for (int i = 0; i < plugins.length; i++)
        _AnimatedPluginMoveWrapper(
          key: _moveWrapperKeys.putIfAbsent(
              plugins[i].pluginId, () => GlobalKey()),
          child: _DraggableSettingsPluginRow(
            plugin: plugins[i],
            isSelectionMode: _isSelectionMode,
            selected: _selectedIds.contains(plugins[i].pluginId),
            onSelectChanged: (v) => _toggleSelection(plugins[i].pluginId, v),
            isFirst: i == 0,
            isLast: i == plugins.length - 1,
            onMoveUp: i == 0 ? null : () => _handleMove(plugins, i, i - 1),
            onMoveDown: i == plugins.length - 1
                ? null
                : () => _handleMove(plugins, i, i + 1),
            onAcceptSource: (sourceId) => _handleReorder(
              context: context,
              allPlugins: plugins,
              sourcePluginId: sourceId,
              targetPluginId: plugins[i].pluginId,
            ),
            onToggleHide: () => _togglePluginHide(plugins[i]),
            onTogglePinNavRail: () => _togglePluginPinNavRail(plugins[i]),
            onToggleEnabled: () => _togglePluginEnabled(plugins[i]),
            onDelete: () => _deletePlugin(plugins[i]),
          ),
        ),
    ];
  }

  void _handleMove(List<InstalledPlugin> plugins, int from, int to) {
    final movedId = plugins[from].pluginId;
    final movedUp = to < from;
    final reordered = List.of(plugins);
    final item = reordered.removeAt(from);
    reordered.insert(to, item);
    final ids = reordered.map((p) => p.pluginId).toList();
    // Defer dispatch so the BlocBuilder rebuilds during the normal build phase
    // of the next frame, not inside a LayoutBuilder's _rebuildWithConstraints.
    // Without deferral, GlobalKey reactivation of rows with Tooltip/OverlayPortal
    // happens during the LayoutBuilder's buildScope → Flutter rendering crash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PluginSystemBloc>().add(ReorderPluginsRequested(ids));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveWrapperKeys[movedId]
            ?.currentState
            ?.playAnimation(movedUp: movedUp);
      });
    });
  }

  void _handleReorder({
    required BuildContext context,
    required List<InstalledPlugin> allPlugins,
    required String sourcePluginId,
    required String targetPluginId,
  }) {
    final sourceIdx =
        allPlugins.indexWhere((p) => p.pluginId == sourcePluginId);
    final targetIdx =
        allPlugins.indexWhere((p) => p.pluginId == targetPluginId);
    if (sourceIdx < 0 || targetIdx < 0) return;
    final reordered = List.of(allPlugins);
    final src = reordered.removeAt(sourceIdx);
    reordered.insert(targetIdx, src);
    final ids = reordered.map((p) => p.pluginId).toList();
    // Same deferral as _handleMove: prevents LayoutBuilder + BlocBuilder
    // dirty collision that causes OverlayPortal reactivation crash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      this.context.read<PluginSystemBloc>().add(ReorderPluginsRequested(ids));
    });
  }

  /// מנקה מזהי תוספים נבחרים שאינם רלוונטיים עוד (תוסף שהוסר). חייב לקרות
  /// בתוך build כי הנתונים מגיעים מ-BlocBuilder.
  void _pruneStaleSelection(List<InstalledPlugin> plugins) {
    if (_selectedIds.isEmpty) return;
    // plugins ריק = מצב טעינה; אל נקה את הבחירה בינתיים, כי ה-IDs עדיין תקינים.
    if (plugins.isEmpty) return;
    final validIds = <String>{for (final p in plugins) p.pluginId};
    final stale = _selectedIds.difference(validIds);
    if (stale.isNotEmpty) {
      // setState אסורה ב-build; מזיזים את ההסרה לאחר ה-frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedIds.removeAll(stale));
      });
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// סרגל הפעולות (תוספים בלבד)
// ──────────────────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final Set<String> selectedIds;
  final List<InstalledPlugin> plugins;

  const _ActionBar({
    required this.selectedIds,
    required this.plugins,
  });

  Iterable<InstalledPlugin> get _selectedPlugins =>
      plugins.where((p) => selectedIds.contains(p.pluginId));

  /// האם כל התוספים שנבחרו כבר מוסתרים ממסך הכלים?
  bool get _allSelectedHiddenFromTools {
    final selected = _selectedPlugins;
    return selected.isNotEmpty && selected.every((p) => !p.showInTools);
  }

  /// האם כל התוספים שנבחרו כבר מוצמדים ל-nav rail?
  bool get _allSelectedArePinnedToNav {
    final selected = _selectedPlugins;
    return selected.isNotEmpty && selected.every((p) => p.pinnedToNavRail);
  }

  bool get _allSelectedPluginsEnabled =>
      _selectedPlugins.every((p) => p.enabled);

  bool get _allSelectedHaveNetworkAccess {
    final eligible = _selectedPlugins
        .where((p) => p.manifest.permissions.contains(_networkAccessPermission))
        .toList();
    return eligible.isNotEmpty && eligible.every((p) => p.networkAccessGranted);
  }

  bool get _anySelectedHasNetworkPermission => _selectedPlugins
      .any((p) => p.manifest.permissions.contains(_networkAccessPermission));

  bool get _allSelectedHaveStartupEnabled {
    final eligible = _selectedPlugins
        .where((p) =>
            p.manifest.permissions.contains(pluginRunOnStartupPermission))
        .toList();
    return eligible.isNotEmpty && eligible.every((p) => p.runOnStartupGranted);
  }

  bool get _anySelectedHasStartupPermission => _selectedPlugins.any(
      (p) => p.manifest.permissions.contains(pluginRunOnStartupPermission));

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedIds.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionButton.neutral(
              icon: _allSelectedHiddenFromTools
                  ? FluentIcons.eye_24_regular
                  : FluentIcons.eye_off_24_regular,
              text: _allSelectedHiddenFromTools ? 'הצג' : 'הסתר',
              onPressed:
                  hasSelection ? () => _onToggleShowInTools(context) : null,
            ),
            ActionButton.neutral(
              icon: _allSelectedArePinnedToNav
                  ? FluentIcons.pin_24_filled
                  : FluentIcons.pin_24_regular,
              text: _allSelectedArePinnedToNav ? 'הסר מניווט' : 'הצמד לניווט',
              onPressed:
                  hasSelection ? () => _onTogglePinNavRail(context) : null,
            ),
            ActionButton.neutral(
              icon: _allSelectedPluginsEnabled
                  ? FluentIcons.pause_circle_24_regular
                  : FluentIcons.play_circle_24_regular,
              text: _allSelectedPluginsEnabled ? 'השבת' : 'הפעל',
              onPressed: hasSelection ? () => _onToggleEnabled(context) : null,
            ),
            ActionButton.neutral(
              icon: _allSelectedHaveNetworkAccess
                  ? FluentIcons.globe_prohibited_24_regular
                  : FluentIcons.globe_24_regular,
              text: _allSelectedHaveNetworkAccess ? 'דחיה מהרשת' : 'גישה לרשת',
              onPressed: hasSelection && _anySelectedHasNetworkPermission
                  ? () => _setNetworkAccess(context,
                      granted: !_allSelectedHaveNetworkAccess)
                  : null,
            ),
            ActionButton.neutral(
              icon: _allSelectedHaveStartupEnabled
                  ? FluentIcons.power_24_filled
                  : FluentIcons.power_24_regular,
              text: _allSelectedHaveStartupEnabled
                  ? 'טעינה רגילה'
                  : 'טעינה בעליה',
              onPressed: hasSelection && _anySelectedHasStartupPermission
                  ? () => _setRunOnStartup(context,
                      granted: !_allSelectedHaveStartupEnabled)
                  : null,
            ),
            ActionButton.ghost(
              icon: FluentIcons.delete_24_regular,
              text: 'מחק',
              onPressed: hasSelection ? () => _onDelete(context) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _onToggleShowInTools(BuildContext context) {
    final shouldShow = _allSelectedHiddenFromTools;
    final bloc = context.read<PluginSystemBloc>();
    for (final p in _selectedPlugins) {
      bloc.add(SetPluginShowInToolsRequested(
        pluginId: p.pluginId,
        showInTools: shouldShow,
      ));
    }
    UiSnack.show(shouldShow ? 'התוספים יוצגו בכלים' : 'התוספים הוסרו מהכלים');
  }

  void _onTogglePinNavRail(BuildContext context) {
    final shouldPin = !_allSelectedArePinnedToNav;
    final bloc = context.read<PluginSystemBloc>();
    for (final p in _selectedPlugins) {
      if (shouldPin) {
        bloc.add(PinPluginToNavRailRequested(p.pluginId));
      } else {
        bloc.add(UnpinPluginFromNavRailRequested(p.pluginId));
      }
    }
  }

  void _onToggleEnabled(BuildContext context) {
    final shouldEnable = !_allSelectedPluginsEnabled;
    final bloc = context.read<PluginSystemBloc>();
    for (final p in _selectedPlugins) {
      if (shouldEnable) {
        bloc.add(EnablePluginRequested(p.pluginId));
      } else {
        bloc.add(DisablePluginRequested(p.pluginId));
      }
    }
  }

  void _setNetworkAccess(BuildContext context, {required bool granted}) {
    final bloc = context.read<PluginSystemBloc>();
    var updated = false;
    for (final p in _selectedPlugins) {
      for (final permission in _networkPermissions) {
        if (!p.manifest.permissions.contains(permission)) continue;
        bloc.add(SetPluginPermissionRequested(
          pluginId: p.pluginId,
          permission: permission,
          granted: granted,
        ));
        updated = true;
      }
    }
    if (!updated) {
      UiSnack.showError('אף תוסף נבחר לא מצהיר על שימוש ברשת — אין מה לעדכן');
      return;
    }
    UiSnack.show(granted
        ? 'גישה לרשת הוענקה לתוספים הנבחרים'
        : 'גישה לרשת בוטלה לתוספים הנבחרים');
  }

  void _setRunOnStartup(BuildContext context, {required bool granted}) {
    final eligible = _selectedPlugins
        .where((p) =>
            p.manifest.permissions.contains(pluginRunOnStartupPermission))
        .toList();
    if (eligible.isEmpty) {
      UiSnack.showError('אף תוסף נבחר לא תומך בטעינה אוטומטית בעלייה');
      return;
    }
    final bloc = context.read<PluginSystemBloc>();
    for (final p in eligible) {
      bloc.add(SetPluginPermissionRequested(
        pluginId: p.pluginId,
        permission: pluginRunOnStartupPermission,
        granted: granted,
      ));
    }
    UiSnack.show(granted
        ? 'טעינה אוטומטית בעלייה הופעלה לתוספים הנבחרים'
        : 'טעינה אוטומטית בעלייה בוטלה לתוספים הנבחרים');
  }

  Future<void> _onDelete(BuildContext context) async {
    final plugins = _selectedPlugins.toList();
    if (plugins.isEmpty) return;
    final names = plugins.map((p) => p.name).join('\n• ');
    // קוראים ל-bloc *לפני* ה-await כדי לא להחזיק BuildContext חוצה גבולות async
    final bloc = context.read<PluginSystemBloc>();
    final confirmed = await showWarningDialog(
      context: context,
      title: 'מחיקת תוספים',
      content: 'האם למחוק ${plugins.length} תוסף(ים)?\n\n• $names',
      subtitle: 'פעולה זו אינה הפיכה! נתוני התוסף יימחקו.',
      confirmText: 'מחק',
    );
    if (confirmed != true) return;
    for (final p in plugins) {
      if (p.isDevelopment) {
        bloc.add(DetachDevelopmentPluginRequested(p.pluginId));
      } else {
        bloc.add(UninstallPluginRequested(p.pluginId));
      }
    }
    UiSnack.show('התוספים סומנו למחיקה');
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// שורות הטבלה
// ──────────────────────────────────────────────────────────────────────────────

/// שורת כלי מובנה — ללא תיבת סימון; שני לחצני פעולה ישירים בצד.
class _BuiltInToolRow extends StatelessWidget {
  final BuiltInToolMeta meta;
  final bool hidden;
  final bool pinnedToNavRail;
  final VoidCallback onToggleHide;
  final VoidCallback onTogglePin;

  const _BuiltInToolRow({
    required this.meta,
    required this.hidden,
    required this.pinnedToNavRail,
    required this.onToggleHide,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    // SettingsActionTile uses LayoutBuilder internally, which conflicts with
    // Tooltip's OverlayPortal when elements re-activate during layout. Use
    // ListTile directly for all cases.
    return ListTile(
      hoverColor: Colors.transparent,
      leading: meta.imageIcon != null
          ? ImageIcon(AssetImage(meta.imageIcon!), size: 24)
          : Icon(meta.icon),
      title: Text(meta.label, style: AppTextStyles.settingTitle),
      subtitle: _StatusBadges(hidden: hidden, pinnedToNavRail: pinnedToNavRail),
      trailing: _buildTrailing(),
    );
  }

  Row _buildTrailing() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: hidden ? 'הצג בממשק' : 'הסתר מהממשק',
            isSelected: !hidden,
            icon: Icon(FluentIcons.eye_off_24_regular),
            selectedIcon: Icon(FluentIcons.eye_24_regular),
            onPressed: onToggleHide,
          ),
          AnimatedPinButton(
            tooltip: pinnedToNavRail ? 'הסר מסרגל הניווט' : 'הצמד לסרגל הניווט',
            isPinned: pinnedToNavRail,
            onPressed: onTogglePin,
          ),
        ],
      );
}

class _DraggableSettingsPluginRow extends StatelessWidget {
  final InstalledPlugin plugin;
  final bool isSelectionMode;
  final bool selected;
  final ValueChanged<bool?> onSelectChanged;
  final ValueChanged<String> onAcceptSource;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onToggleHide;
  final VoidCallback onTogglePinNavRail;
  final VoidCallback onToggleEnabled;
  final VoidCallback onDelete;

  const _DraggableSettingsPluginRow({
    required this.plugin,
    required this.isSelectionMode,
    required this.selected,
    required this.onSelectChanged,
    required this.onAcceptSource,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleHide,
    required this.onTogglePinNavRail,
    required this.onToggleEnabled,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != plugin.pluginId,
      onAcceptWithDetails: (details) => onAcceptSource(details.data),
      builder: (context, candidateData, _) {
        final isHovering = candidateData.isNotEmpty;
        final cs = Theme.of(context).colorScheme;
        return Container(
          decoration: isHovering
              ? BoxDecoration(
                  color: AppSurfaces.dragTargetHighlight(cs),
                  border: Border(
                    top: BorderSide(color: cs.primary, width: 2),
                  ),
                )
              : null,
          child: Material(
            color: Colors.transparent,
            child: _PluginRow(
              plugin: plugin,
              isSelectionMode: isSelectionMode,
              selected: selected,
              onSelectChanged: onSelectChanged,
              isFirst: isFirst,
              isLast: isLast,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
              onToggleHide: onToggleHide,
              onTogglePinNavRail: onTogglePinNavRail,
              onToggleEnabled: onToggleEnabled,
              onDelete: onDelete,
              dragHandle: Draggable<String>(
                data: plugin.pluginId,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: _SettingsDragFeedback(plugin: plugin),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Tooltip(
                    message: 'גרור ושחרר לשינוי סדר',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        FluentIcons.re_order_dots_vertical_24_regular,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PluginRow extends StatelessWidget {
  final InstalledPlugin plugin;
  final bool isSelectionMode;
  final bool selected;
  final ValueChanged<bool?> onSelectChanged;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onToggleHide;
  final VoidCallback onTogglePinNavRail;
  final VoidCallback onToggleEnabled;
  final VoidCallback onDelete;
  final Widget? dragHandle;

  const _PluginRow({
    required this.plugin,
    required this.isSelectionMode,
    required this.selected,
    required this.onSelectChanged,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleHide,
    required this.onTogglePinNavRail,
    required this.onToggleEnabled,
    required this.onDelete,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final icon = fluentIconFromName(plugin.manifest.toolTabIconName) ??
        FluentIcons.puzzle_piece_24_regular;
    return ListTile(
      hoverColor: Colors.transparent,
      leading: isSelectionMode
          ? SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: selected,
                onChanged: onSelectChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          : null,
      title: isSelectionMode
          ? Text(plugin.name)
          : Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(plugin.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
      subtitle: _StatusBadges(
        version: plugin.version,
        hidden: !plugin.showInTools,
        pinnedToNavRail: plugin.pinnedToNavRail,
        disabled: !plugin.enabled,
        networkDeclared: plugin.networkAccessGranted,
        networkRevoked:
            plugin.manifest.networkEnabled && !plugin.networkAccessGranted,
      ),
      trailing: isSelectionMode
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActionButton.ghost(
                  icon: FluentIcons.arrow_up_24_regular,
                  text: 'הזז למעלה',
                  onPressed: isFirst ? null : onMoveUp,
                ),
                const SizedBox(width: 8),
                ActionButton.ghost(
                  icon: FluentIcons.arrow_down_24_regular,
                  text: 'הזז למטה',
                  onPressed: isLast ? null : onMoveDown,
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.shield_24_regular),
                  tooltip: 'ניהול הרשאות',
                  onPressed: () => showPluginSettingsDialog(context, plugin),
                ),
                AnimatedPinButton(
                  isPinned: plugin.pinnedToNavRail,
                  tooltip: plugin.pinnedToNavRail
                      ? 'הסר מסרגל הניווט'
                      : 'הצמד לסרגל הניווט',
                  onPressed: onTogglePinNavRail,
                ),
                IconButton(
                  tooltip: !plugin.showInTools ? 'הצג בממשק' : 'הסתר מהממשק',
                  isSelected: !!plugin.showInTools,
                  icon: Icon(FluentIcons.eye_off_24_regular),
                  selectedIcon: Icon(FluentIcons.eye_24_regular),
                  onPressed: onToggleHide,
                ),
                IconButton(
                  tooltip: plugin.enabled ? 'השבת' : 'הפעל',
                  isSelected: !plugin.enabled,
                  icon: const Icon(FluentIcons.pause_circle_24_regular),
                  selectedIcon: const Icon(FluentIcons.play_circle_24_regular),
                  onPressed: onToggleEnabled,
                ),
                IconButton(
                  tooltip: 'מחק תוסף',
                  icon: const Icon(FluentIcons.delete_24_regular),
                  onPressed: onDelete,
                ),
                if (dragHandle != null) dragHandle!,
              ],
            ),
      onTap: isSelectionMode ? () => onSelectChanged(!selected) : null,
    );
  }
}

class _AnimatedPluginMoveWrapper extends StatefulWidget {
  final Widget child;

  const _AnimatedPluginMoveWrapper({
    super.key,
    required this.child,
  });

  @override
  State<_AnimatedPluginMoveWrapper> createState() =>
      _AnimatedPluginMoveWrapperState();
}

class _AnimatedPluginMoveWrapperState extends State<_AnimatedPluginMoveWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  bool _movedUp = true;

  void playAnimation({required bool movedUp}) {
    _movedUp = movedUp;
    _ctrl.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
      value: 1.0,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final slideSign = _movedUp ? 1.0 : -1.0;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final t = _progress.value;
        final slideY = slideSign * 0.25 * (1.0 - t);
        final shadowAlpha = 0.28 * (1.0 - t);
        final bgAlpha = 0.10 * (1.0 - t);
        return FractionalTranslation(
          translation: Offset(0, slideY),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: bgAlpha),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: shadowAlpha),
                  blurRadius: 8.0 * (1.0 - t),
                  offset: Offset(0, 4.0 * (1.0 - t)),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _SettingsDragFeedback extends StatelessWidget {
  final InstalledPlugin plugin;

  const _SettingsDragFeedback({required this.plugin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: AppTokens.borderRadiusAll,
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(fluentIconFromName(plugin.manifest.toolTabIconName) ??
                FluentIcons.puzzle_piece_24_regular),
            const SizedBox(width: 8),
            Text(
              plugin.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// תגיות סטטוס לשורת כלי/תוסף — אייקונים בלבד; ההסבר מופיע ב-tooltip בריחוף.
class _StatusBadges extends StatelessWidget {
  final String? version;
  final bool hidden;
  final bool pinnedToNavRail;
  final bool disabled;
  final bool networkDeclared;

  final bool networkRevoked;

  const _StatusBadges({
    this.version,
    this.hidden = false,
    this.pinnedToNavRail = false,
    this.disabled = false,
    this.networkDeclared = false,
    this.networkRevoked = false,
  });

  bool get hasAny =>
      hidden ||
      pinnedToNavRail ||
      disabled ||
      networkDeclared ||
      networkRevoked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <Widget>[];
    if (version != null) {
      chips.add(Text('v$version', style: AppTextStyles.settingSubtitle));
    }
    if (disabled) {
      chips.add(_badge(context, 'מושבת', cs.errorContainer, cs.onErrorContainer,
          FluentIcons.pause_circle_24_regular));
    }
    if (hidden) {
      chips.add(_badge(context, 'מוסתר', cs.surfaceContainerHighest,
          cs.onSurfaceVariant, FluentIcons.eye_off_24_regular));
    }
    if (pinnedToNavRail) {
      chips.add(_badge(context, 'בסרגל ניווט', cs.primaryContainer,
          cs.onPrimaryContainer, FluentIcons.pin_24_regular));
    }
    if (networkDeclared) {
      chips.add(_badge(context, 'משתמש ברשת', cs.tertiaryContainer,
          cs.onTertiaryContainer, FluentIcons.globe_24_regular));
    }
    if (networkRevoked) {
      chips.add(_badge(context, 'מנותק מהרשת', cs.errorContainer,
          cs.onErrorContainer, FluentIcons.globe_prohibited_24_regular));
    }
    // ה-Stack מגדיר גובה קבוע: placeholder בלתי-נראה מרנדר תמיד (badge הגבוה ביותר
    // האפשרי) ומחזיק את הגובה; ה-chips האמיתיים מונחים מעליו.
    // כך גובה ה-subtitle קבוע בכל מצב — גם כשאין תגים וגם כשיש אחד או שניים.
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: _badge(context, 'בסרגל ניווט', cs.primaryContainer,
                cs.onPrimaryContainer, FluentIcons.pin_24_regular),
          ),
          if (chips.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < chips.length; i++) ...[
                  chips[i],
                  if (i < chips.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _badge(
      BuildContext context, String tooltip, Color bg, Color fg, IconData icon) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: RtlIcon(icon, size: 14, color: fg),
      ),
    );
  }
}
