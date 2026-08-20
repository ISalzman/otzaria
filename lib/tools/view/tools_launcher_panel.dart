import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/view/plugin_actions.dart';
import 'package:otzaria/plugins/view/plugin_settings_screen.dart';
import 'package:otzaria/plugins/view/widgets/plugin_drop_zone.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/settings/services/safer_mode_guard.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/combined_tab.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/tools/built_in_tools_catalog.dart';
import 'package:otzaria/tools/tool_catalog_entry.dart';
import 'package:otzaria/tools/tool_order.dart';
import 'package:otzaria/widgets/controls/action_buttons.dart';
import 'package:otzaria/widgets/dialogs/dialogs_exports.dart';
import 'package:otzaria/widgets/feedback/edge_scrollbar_behavior.dart';
import 'package:otzaria/widgets/lists/nav_tree_tile.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';

const String kBuiltInToolsGroupLabel = 'כלים';
const String kPluginsGroupLabel = 'תוספים';

/// מנרמל טקסט להשוואת חיפוש: גרשיים, מקפים וניקוד אינם אמורים למנוע התאמה.
@visibleForTesting
String normalizeToolSearchText(String value) {
  return value
      .replaceAll(RegExp(r'[֑-ׇ]'), '')
      .replaceAll(RegExp(r'''["'`׳״\-–—]'''), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

/// מסנן רשומות לפי מחרוזת חיפוש, מול התווית ומול שם התוסף.
@visibleForTesting
List<ToolCatalogEntry> filterToolEntries(
  List<ToolCatalogEntry> entries,
  String query,
) {
  final normalized = normalizeToolSearchText(query);
  if (normalized.isEmpty) return entries;
  return entries.where((entry) {
    if (normalizeToolSearchText(entry.label).contains(normalized)) return true;
    final pluginName = entry.plugin?.name;
    return pluginName != null &&
        normalizeToolSearchText(pluginName).contains(normalized);
  }).toList();
}

typedef ToolGroup = ({String label, List<ToolCatalogEntry> entries});

/// מקבץ רשומות עוקבות לפי סוגן בלי לשנות את סדר הקטלוג.
///
/// הפיצול הוא גם לפי קבוצת המיון, ולא לפי התווית בלבד: כשכל הכלים המובנים
/// מוסתרים, שתי קבוצות התוספים (זו שהורשתה להקדים אותם וזו הרגילה) נהיות
/// עוקבות, וקבוצה מאוחדת הייתה מייצרת פעולות הזזה פעילות שאינן עושות דבר.
@visibleForTesting
List<ToolGroup> groupToolEntries(List<ToolCatalogEntry> entries) {
  final groups = <ToolGroup>[];
  int? lastPriority;
  for (final entry in entries) {
    final label = entry.isPlugin ? kPluginsGroupLabel : kBuiltInToolsGroupLabel;
    if (groups.isNotEmpty &&
        groups.last.label == label &&
        lastPriority == entry.sortGroupPriority) {
      groups.last.entries.add(entry);
    } else {
      groups.add((label: label, entries: [entry]));
    }
    lastPriority = entry.sortGroupPriority;
  }
  return groups;
}

/// סדר השורות כפי שהן מוצגות בפועל.
@visibleForTesting
List<ToolCatalogEntry> orderedToolEntries(List<ToolCatalogEntry> entries) => [
  for (final group in groupToolEntries(entries)) ...group.entries,
];

/// האינדקס המסומן הבא בניווט מקלדת. `-1` = אין סימון, והחץ הראשון מסמן את
/// השורה הראשונה.
@visibleForTesting
int nextHighlightIndex({
  required int current,
  required int delta,
  required int total,
}) {
  if (total <= 0) return 0;
  // ממצב "אין סימון" כל חץ מסמן את השורה הראשונה, ולא מדלג delta שורות.
  if (current < 0) return 0;
  return (current + delta).clamp(0, total - 1);
}

/// האם שתי רשומות שייכות לאותה קבוצת תצוגה, כלומר האם מותר לסדר ביניהן.
///
/// כלי מובנה ותוסף אינם מתערבבים, וגם תוסף שהורשה להקדים את הכלים המובנים
/// יושב בקבוצה נפרדת מתוסף רגיל.
@visibleForTesting
bool canReorderBetween(ToolCatalogEntry source, ToolCatalogEntry target) =>
    source.toolId != target.toolId &&
    source.isPlugin == target.isPlugin &&
    source.sortGroupPriority == target.sortGroupPriority;

/// פעולה בתפריט השורה. מקור אמת אחד — נצרך גם בכפתור ⋯ וגם בבדיקות.
/// [onTap] ריק (`null`) = הפעולה מוצגת מעומעמת (למשל הזזה בקצה הקבוצה).
/// [children] הופך את הפעולה לתת-תפריט, ואז [onTap] אינו בשימוש.
@visibleForTesting
class ToolTileAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  /// מפריד מעל הפעולה — מפריד את הפעולות ההרסניות משאר התפריט.
  final bool dividerBefore;

  final List<ToolTileAction>? children;

  const ToolTileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.dividerBefore = false,
    this.children,
  });
}

/// תוכן פאנל הכלים: חיפוש למעלה, ומתחתיו רשימת עץ ניווט מקובצת.
class ToolsLauncherPanel extends StatefulWidget {
  final ValueChanged<ToolCatalogEntry> onToolSelected;
  final VoidCallback onClose;
  final bool showDevTools;

  const ToolsLauncherPanel({
    super.key,
    required this.onToolSelected,
    required this.onClose,
    this.showDevTools = kDebugMode,
  });

  @override
  State<ToolsLauncherPanel> createState() => _ToolsLauncherPanelState();
}

class _ToolsLauncherPanelState extends State<ToolsLauncherPanel> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  late final FocusNode _searchFocusNode = FocusNode(
    onKeyEvent: _handleSearchFieldKey,
  );
  String _query = '';

  /// השורה המסומנת בניווט מקלדת, כאינדקס ברשימה המסוננת השטוחה.
  /// `-1` = אין סימון, כדי שלא ייראה כאילו הכלי הראשון נבחר.
  int _highlightedIndex = -1;
  List<ToolCatalogEntry> _keyboardEntries = const [];

  /// הכלי שזז אחרון ומספר ההזזה — מריצים פעימת הדגשה על השורה שזזה.
  String? _movedToolId;
  int _moveNonce = 0;

  /// הסדר ששוגר וטרם חזר מה-bloc. בסיס לחישוב הזזה נוספת שמגיעה לפני שהמצב
  /// התיישר. `null` = אין שיגור באוויר.
  List<String>? _pendingBuiltInOrder;
  List<String>? _pendingPluginOrder;

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _installPlugin() async {
    final verified = await verifySaferModePassword(context);
    if (!verified || !mounted) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['otzplugin'],
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    context.read<PluginSystemBloc>().add(InstallPluginRequested(path));
  }

  Future<void> _loadDevPlugin() async {
    final verified = await verifySaferModePassword(context);
    if (!verified || !mounted) return;
    final rootPath = await FilePicker.getDirectoryPath(lockParentWindow: true);
    if (rootPath == null || !mounted) return;
    context.read<PluginSystemBloc>().add(
      LoadDevelopmentPluginRequested(rootPath),
    );
  }

  Future<void> _loadLocalhostPlugin() async {
    final verified = await verifySaferModePassword(context);
    if (!verified || !mounted) return;
    final bloc = context.read<PluginSystemBloc>();
    final url = await showInputDialog(
      context: context,
      title: 'טעינת תוסף מ-localhost',
      labelText: 'Base URL',
      hintText: 'http://localhost:3000',
      initialValue: 'http://localhost:3000',
      cancelText: 'ביטול',
      confirmText: 'טען',
    );
    if (url == null || url.isEmpty) return;
    bloc.add(LoadLocalhostPluginRequested(url));
  }

  void _moveHighlight(int delta, int total) {
    if (total == 0) return;
    setState(() {
      _highlightedIndex = nextHighlightIndex(
        current: _highlightedIndex,
        delta: delta,
        total: total,
      );
    });
  }

  void _activateHighlighted(List<ToolCatalogEntry> entries) {
    if (entries.isEmpty) return;
    widget.onToolSelected(
      entries[_highlightedIndex.clamp(0, entries.length - 1)],
    );
  }

  /// חצי מעלה/מטה מזיזים את הסימון; חצי ימין/שמאל נשארים לטקסט שבשדה החיפוש.
  KeyEventResult _handleKey(KeyEvent event, List<ToolCatalogEntry> entries) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onClose();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveHighlight(1, entries.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveHighlight(-1, entries.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _activateHighlighted(entries);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSearchFieldKey(FocusNode _, KeyEvent event) =>
      _handleKey(event, _keyboardEntries);

  // ── סידור מחדש ──────────────────────────────────────────────────────────────

  /// סידור אפשרי רק ברשימה המלאה: בחיפוש השורות מסוננות, ו"השכן" על המסך
  /// אינו השכן האמיתי בסדר.
  bool get _isReorderEnabled => normalizeToolSearchText(_query).isEmpty;

  void _reorder({
    required ToolCatalogEntry source,
    required ToolCatalogEntry target,
    required bool placeAfter,
  }) {
    if (!canReorderBetween(source, target)) return;
    final pluginBloc = context.read<PluginSystemBloc>();
    final settingsBloc = context.read<SettingsBloc>();

    // שיגור מושהה לפריים הבא: שיגור בזמן בניית הרשימה מפיל את Flutter על
    // הפעלה-מחדש של רכיבי Overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (source.isPlugin) {
        final pluginState = pluginBloc.state;
        if (pluginState is! PluginSystemLoaded) return;
        // הסדר ששוגר לפני רגע הוא הבסיס עד שה-bloc מתיישר, אחרת הזזה שנייה
        // מהירה מחושבת מהסדר הישן ומוחקת את הראשונה.
        final base =
            _pendingPluginOrder ??
            pluginState.plugins.map((plugin) => plugin.pluginId).toList();
        final ordered = reorderIdsAroundTarget(
          base,
          source.toolId,
          target.toolId,
          placeAfter: placeAfter,
        );
        _pendingPluginOrder = ordered;
        pluginBloc.add(ReorderPluginsRequested(ordered));
      } else {
        final ordered = reorderedBuiltInToolIds(
          _pendingBuiltInOrder ?? settingsBloc.state.builtInToolsOrder,
          source.toolId,
          target.toolId,
          placeAfter: placeAfter,
        );
        _pendingBuiltInOrder = ordered;
        settingsBloc.add(UpdateBuiltInToolsOrder(ordered));
      }
      setState(() {
        _movedToolId = source.toolId;
        _moveNonce++;
      });
    });
  }

  /// מנקה את הסדר הממתין ברגע שה-bloc התיישר עליו. חייב לקרות ב-build, כי שם
  /// מגיע ה-state המעודכן.
  void _clearSettledPendingOrders(
    SettingsState settingsState,
    PluginSystemState pluginState,
  ) {
    final pendingBuiltIn = _pendingBuiltInOrder;
    if (pendingBuiltIn != null &&
        const ListEquality<String>().equals(
          settingsState.builtInToolsOrder,
          pendingBuiltIn,
        )) {
      _pendingBuiltInOrder = null;
    }
    final pendingPlugins = _pendingPluginOrder;
    if (pendingPlugins != null && pluginState is PluginSystemLoaded) {
      final current = pluginState.plugins
          .map((plugin) => plugin.pluginId)
          .toList();
      // גם כשקבוצת התוספים עצמה השתנתה (התקנה, הסרה, כישלון בשמירה) הבסיס
      // הממתין אינו רלוונטי — אחרת הוא היה נשאר לנצח ומשגר סדר חסר מזהה.
      if (const ListEquality<String>().equals(current, pendingPlugins) ||
          !const SetEquality<String>().equals(
            current.toSet(),
            pendingPlugins.toSet(),
          )) {
        _pendingPluginOrder = null;
      }
    }
  }

  /// פעולות השורה, בסדר שבו הן מוצגות בתפריט ⋯.
  List<ToolTileAction> _tileActions(
    ToolCatalogEntry entry, {
    required VoidCallback? onMoveEarlier,
    required VoidCallback? onMoveLater,
    required VoidCallback? onMoveToStart,
    required VoidCallback? onMoveToEnd,
  }) {
    final plugin = entry.plugin;
    return [
      ToolTileAction(
        icon: FluentIcons.re_order_dots_vertical_24_regular,
        label: 'הזזה',
        onTap: null,
        children: [
          // RtlIcon בשורת התפריט מהפך את החץ, כך שיצביע לכיוון ההזזה בפועל.
          ToolTileAction(
            icon: FluentIcons.arrow_left_24_regular,
            label: 'הזז אחורה',
            onTap: onMoveEarlier,
          ),
          ToolTileAction(
            icon: FluentIcons.arrow_right_24_regular,
            label: 'הזז קדימה',
            onTap: onMoveLater,
          ),
          ToolTileAction(
            icon: FluentIcons.arrow_previous_24_regular,
            label: 'הזז לתחילה',
            onTap: onMoveToStart,
          ),
          ToolTileAction(
            icon: FluentIcons.arrow_next_24_regular,
            label: 'הזז לסוף',
            onTap: onMoveToEnd,
          ),
        ],
      ),
      if (plugin != null)
        ToolTileAction(
          icon: FluentIcons.shield_24_regular,
          label: 'ניהול הרשאות',
          onTap: () => showPluginSettingsDialog(context, plugin),
        ),
      ToolTileAction(
        icon: _isPinnedToNavRail(entry)
            ? FluentIcons.pin_off_24_regular
            : FluentIcons.pin_24_regular,
        label: _isPinnedToNavRail(entry)
            ? 'הסר מסרגל הניווט'
            : 'הצמד לסרגל הניווט',
        onTap: () => _togglePinToNavRail(entry),
      ),
      ToolTileAction(
        // תוסף מוצמד לסרגל הניווט נשאר בקטלוג גם כשהוא מוסתר, ולכן התווית
        // חייבת לשקף את מצבו בפועל — אחרת הלחיצה הבאה מחזירה אותו בשקט.
        icon: (plugin?.showInTools ?? true)
            ? FluentIcons.eye_off_24_regular
            : FluentIcons.eye_24_regular,
        label: (plugin?.showInTools ?? true) ? 'הסתר מהממשק' : 'הצג בממשק',
        onTap: () => _hideFromInterface(entry),
      ),
      if (plugin != null)
        ToolTileAction(
          icon: plugin.enabled
              ? FluentIcons.pause_circle_24_regular
              : FluentIcons.play_circle_24_regular,
          label: plugin.enabled ? 'השבת' : 'הפעל',
          onTap: () => togglePluginEnabled(context, plugin),
        ),
      if (plugin != null)
        ToolTileAction(
          icon: FluentIcons.delete_24_regular,
          label: 'מחק תוסף',
          isDestructive: true,
          dividerBefore: true,
          onTap: () => showDeletePluginDialog(context, plugin),
        ),
    ];
  }

  bool _isPinnedToNavRail(ToolCatalogEntry entry) =>
      entry.plugin?.pinnedToNavRail ??
      context.read<SettingsBloc>().state.builtInToolsPinnedToNavRail.contains(
        entry.toolId,
      );

  void _togglePinToNavRail(ToolCatalogEntry entry) {
    final plugin = entry.plugin;
    if (plugin != null) {
      togglePluginPinnedToNavRail(context, plugin);
      return;
    }
    final bloc = context.read<SettingsBloc>();
    final next = Set<String>.from(bloc.state.builtInToolsPinnedToNavRail);
    if (!next.add(entry.toolId)) next.remove(entry.toolId);
    bloc.add(UpdateBuiltInToolsPinnedToNavRail(next));
  }

  void _hideFromInterface(ToolCatalogEntry entry) {
    final plugin = entry.plugin;
    if (plugin != null) {
      togglePluginShowInTools(context, plugin);
      return;
    }
    final bloc = context.read<SettingsBloc>();
    final next = Set<String>.from(bloc.state.hiddenBuiltInToolIds)
      ..add(entry.toolId);
    bloc.add(UpdateHiddenBuiltInToolIds(next));
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<SettingsBloc>().state;
    final pluginState = context.watch<PluginSystemBloc>().state;
    final allEntries = buildToolCatalog(
      hiddenBuiltInToolIds: settingsState.hiddenBuiltInToolIds,
      isOfflineMode: settingsState.isOfflineMode,
      pluginState: pluginState,
      builtInToolsOrder: settingsState.builtInToolsOrder,
    );
    _clearSettledPendingOrders(settingsState, pluginState);
    final entries = orderedToolEntries(filterToolEntries(allEntries, _query));
    // הרשימה התקצרה (כלי הוסתר) — סימון שיצא מהטווח היה נשאר בלי חיווי, אבל
    // Enter היה פותח כלי אחר.
    if (_highlightedIndex >= entries.length) _highlightedIndex = -1;
    final openToolIds = _openToolIds(context.watch<TabsBloc>().state);
    _keyboardEntries = entries;

    return PluginDropZone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: AppTokens.spaceSM),
          _buildSearchField(entries),
          const SizedBox(height: AppTokens.spaceMD),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: entries.isEmpty
                      ? _buildEmptyState(
                          settingsState.isOfflineMode,
                          allEntries,
                        )
                      : _buildList(
                          entries,
                          openToolIds,
                          bottomInset:
                              AppInputTokens.height(
                                settingsState.compactMenuMode,
                              ) +
                              AppTokens.spaceMD,
                        ),
                ),
                PositionedDirectional(
                  bottom: AppTokens.spaceSM,
                  start: kNavTreeSideInset,
                  child: _PluginsToolbar(
                    showDevTools: widget.showDevTools,
                    onInstall: _installPlugin,
                    onLoadFolder: _loadDevPlugin,
                    onLoadLocalhost: _loadLocalhostPlugin,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _openToolIds(TabsState state) => {
    for (final tab in state.tabs)
      for (final pane in leafPanes(tab))
        if (pane is ToolTab) pane.toolId,
  };

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'כלים ותוספים',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppTokens.fontXL,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(FluentIcons.dismiss_24_regular, size: 20),
          tooltip: 'סגור',
          visualDensity: VisualDensity.compact,
          onPressed: widget.onClose,
        ),
      ],
    );
  }

  Widget _buildSearchField(List<ToolCatalogEntry> entries) {
    final field = OtzariaSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      hintText: 'חיפוש כלי או תוסף',
      onChanged: _onQueryChanged,
      onClear: () => _onQueryChanged(''),
      onSubmitted: (_) => _activateHighlighted(entries),
    );

    if (!widget.showDevTools) return field;

    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: AppTokens.spaceXS),
        SquareIconButton.field(
          icon: FluentIcons.arrow_sync_24_regular,
          tooltip: 'רענן תוספים',
          onPressed: () =>
              context.read<PluginSystemBloc>().add(RefreshPlugins()),
        ),
      ],
    );
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      // בחיפוש התוצאה הראשונה מסומנת (Enter יפתח אותה); בלי חיפוש אין סימון.
      _highlightedIndex = normalizeToolSearchText(value).isEmpty ? -1 : 0;
    });
  }

  Widget _buildEmptyState(bool isOfflineMode, List<ToolCatalogEntry> all) {
    final message = _query.trim().isNotEmpty
        ? 'לא נמצאו כלים התואמים לחיפוש'
        : (isOfflineMode
              ? 'אין כלים זמינים במצב מנותק'
              : 'לא נמצאו כלים זמינים');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLG),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildList(
    List<ToolCatalogEntry> entries,
    Set<String> openToolIds, {
    required double bottomInset,
  }) {
    final groups = groupToolEntries(entries);
    var runningIndex = 0;

    return Focus(
      autofocus: false,
      onKeyEvent: (_, event) => _handleKey(event, entries),
      child: NavTreeFocusGroup(
        child: ScrollConfiguration(
          behavior: const EdgeScrollbarBehavior.right(),
          child: ListView(
            controller: _listScrollController,
            padding: kNavTreeListPadding + EdgeInsets.only(bottom: bottomInset),
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                // קבוצות עוקבות באותה תווית (תוספים לפני/אחרי הכלים המובנים)
                // נראות כמקטע אחד — הכותרת מוצגת רק במעבר תווית.
                if (i == 0 || groups[i].label != groups[i - 1].label)
                  NavTreeHeader(title: groups[i].label),
                for (var j = 0; j < groups[i].entries.length; j++)
                  _buildRow(
                    group: groups[i].entries,
                    indexInGroup: j,
                    flatIndex: runningIndex++,
                    openToolIds: openToolIds,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required List<ToolCatalogEntry> group,
    required int indexInGroup,
    required int flatIndex,
    required Set<String> openToolIds,
  }) {
    final entry = group[indexInGroup];
    final canReorder = _isReorderEnabled;
    final isFirst = indexInGroup == 0;
    final isLast = indexInGroup == group.length - 1;
    VoidCallback? moveTo(
      int targetIndex, {
      required bool enabled,
      required bool placeAfter,
    }) => enabled
        ? () => _reorder(
            source: entry,
            target: group[targetIndex],
            placeAfter: placeAfter,
          )
        : null;

    return _ReorderableToolTile(
      key: ValueKey(entry.toolId),
      entry: entry,
      canDrag: canReorder,
      onAcceptSource: (source, {required placeAfter}) =>
          _reorder(source: source, target: entry, placeAfter: placeAfter),
      tile: ToolTile(
        entry: entry,
        isOpen: openToolIds.contains(entry.toolId),
        isHighlighted: flatIndex == _highlightedIndex,
        isGroupStart: isFirst,
        isGroupEnd: isLast,
        movePulse: entry.toolId == _movedToolId ? _moveNonce : 0,
        // בלי זה הפוקוס נשאר על מסלול התפריט שנסגר, ומקשי הפאנל (Escape,
        // חצים, Enter) מפסיקים לעבוד עד לחיצה על שדה החיפוש.
        onMenuClosed: () => _searchFocusNode.requestFocus(),
        actions: _tileActions(
          entry,
          onMoveEarlier: moveTo(
            indexInGroup - 1,
            enabled: canReorder && !isFirst,
            placeAfter: false,
          ),
          onMoveLater: moveTo(
            indexInGroup + 1,
            enabled: canReorder && !isLast,
            placeAfter: true,
          ),
          onMoveToStart: moveTo(
            0,
            enabled: canReorder && !isFirst,
            placeAfter: false,
          ),
          onMoveToEnd: moveTo(
            group.length - 1,
            enabled: canReorder && !isLast,
            placeAfter: true,
          ),
        ),
        onTap: () => widget.onToolSelected(entry),
      ),
    );
  }
}

/// סרגל צף לפעולות התוספים, בתחתית תחילת החלונית — באותו עיצוב של סרגל
/// התצוגה המקדימה בספריה.
class _PluginsToolbar extends StatelessWidget {
  final bool showDevTools;
  final VoidCallback onInstall;
  final VoidCallback onLoadFolder;
  final VoidCallback onLoadLocalhost;

  const _PluginsToolbar({
    required this.showDevTools,
    required this.onInstall,
    required this.onLoadFolder,
    required this.onLoadLocalhost,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      shape: AppTokens.roundedShape,
      elevation: AppTokens.elevation1,
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SquareIconButton.toolbar(
            icon: FluentIcons.add_24_regular,
            tooltip: 'התקן תוסף חדש',
            onPressed: onInstall,
          ),
          if (showDevTools) ...[
            SquareIconButton.toolbar(
              icon: FluentIcons.folder_add_24_regular,
              tooltip: 'טען תיקיית תוסף',
              onPressed: onLoadFolder,
            ),
            SquareIconButton.toolbar(
              icon: FluentIcons.globe_add_24_regular,
              tooltip: 'טען תוסף מ-localhost',
              onPressed: onLoadLocalhost,
            ),
          ],
        ],
      ),
    );
  }
}

/// עוטף שורה ביכולת גרירה לסידור מחדש: גוררים שורה, וקו ההוספה מראה בין אילו
/// שורות היא תיפול — לפי חצי השורה שהסמן נמצא בו, כמו סידור לשוניות בדפדפן.
/// במגע הגרירה מתחילה בלחיצה ארוכה, כדי לא לחטוף את הגלילה.
class _ReorderableToolTile extends StatefulWidget {
  final ToolCatalogEntry entry;
  final ToolTile tile;
  final bool canDrag;
  final void Function(ToolCatalogEntry source, {required bool placeAfter})
  onAcceptSource;

  const _ReorderableToolTile({
    super.key,
    required this.entry,
    required this.tile,
    required this.canDrag,
    required this.onAcceptSource,
  });

  @override
  State<_ReorderableToolTile> createState() => _ReorderableToolTileState();
}

class _ReorderableToolTileState extends State<_ReorderableToolTile> {
  /// `true` = השורה הנגררת תיפול *אחרי* השורה הזאת בסדר.
  bool _placeAfter = false;

  bool get _isTouch => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };

  /// ברשימה אנכית סמן בחצי העליון של השורה מציב לפניה, ובחצי התחתון אחריה.
  void _updateSide(ToolCatalogEntry source, Offset globalPointer) {
    // Flutter מדווח על תזוזה גם ליעדים שנדחו, כולל השורה הנגררת עצמה.
    if (!canReorderBetween(source, widget.entry)) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalPointer);
    final placeAfter = local.dy >= box.size.height / 2;
    if (placeAfter != _placeAfter) setState(() => _placeAfter = placeAfter);
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<ToolCatalogEntry>(
      onWillAcceptWithDetails: (details) =>
          widget.canDrag && canReorderBetween(details.data, widget.entry),
      onMove: (details) => _updateSide(details.data, details.offset),
      onAcceptWithDetails: (details) =>
          widget.onAcceptSource(details.data, placeAfter: _placeAfter),
      builder: (context, candidates, _) {
        final tile = _DropInsertionIndicator(
          placeAfter: candidates.isEmpty ? null : _placeAfter,
          child: widget.tile,
        );
        if (!widget.canDrag) return tile;

        final feedback = _ToolDragFeedback(entry: widget.entry);
        final placeholder = Opacity(opacity: 0.35, child: widget.tile);
        return _isTouch
            ? LongPressDraggable<ToolCatalogEntry>(
                data: widget.entry,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: feedback,
                childWhenDragging: placeholder,
                child: tile,
              )
            : _SlopDraggable<ToolCatalogEntry>(
                data: widget.entry,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: feedback,
                childWhenDragging: placeholder,
                child: tile,
              );
      },
    );
  }
}

/// מרחק התזוזה שממנו לחיצה נחשבת גרירה.
///
/// ה-`Draggable` הרגיל תופס את המחווה כבר בפיקסל אחד בעכבר, ואז לחיצה שבה
/// היד רעדה קלות אינה מגיעה ללחצן שבשורה — הכלי לא נפתח והתפריט לא נפתח.
const double _kToolDragSlop = 12;

/// מזהה גרירה מיידי עם סף תזוזה גדול מברירת המחדל. תומך במצביע מדויק בלבד:
/// במגע הגרירה מתחילה בלחיצה ארוכה, כדי לא לחטוף את הגלילה.
class _SlopMultiDragGestureRecognizer extends MultiDragGestureRecognizer {
  _SlopMultiDragGestureRecognizer({super.debugOwner})
    : super(
        supportedDevices: const {
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      );

  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _SlopPointerState(event.position, event.kind, gestureSettings);

  @override
  String get debugDescription => 'tool tile drag';
}

class _SlopPointerState extends MultiDragPointerState {
  _SlopPointerState(super.initialPosition, super.kind, super.gestureSettings);

  @override
  void checkForResolutionAfterMove() {
    if ((pendingDelta?.distance ?? 0) > _kToolDragSlop) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) =>
      starter(initialPosition);
}

class _SlopDraggable<T extends Object> extends Draggable<T> {
  const _SlopDraggable({
    required super.child,
    required super.feedback,
    super.data,
    super.dragAnchorStrategy,
    super.childWhenDragging,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => _SlopMultiDragGestureRecognizer(debugOwner: this)..onStart = onStart;
}

/// מפתח קו ההוספה שמוצג בגרירה, בצד שאליו השורה תיפול.
@visibleForTesting
const Key kToolDropIndicatorKey = Key('tool-drop-indicator');

/// קו ההוספה בקצה השורה. [placeAfter] ריק = הגרירה אינה מעל השורה הזאת.
class _DropInsertionIndicator extends StatelessWidget {
  static const double lineHeight = 3;

  final bool? placeAfter;
  final Widget child;

  const _DropInsertionIndicator({
    required this.placeAfter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final side = placeAfter;
    if (side == null) return child;
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          // הקו נעצר בשוליים האופקיים של הכרטיס, ולא נמשך אל דופן החלונית.
          start: kNavTreeSideInset,
          end: kNavTreeSideInset,
          top: side ? null : 0,
          bottom: side ? 0 : null,
          child: Container(
            key: kToolDropIndicatorKey,
            height: lineHeight,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(lineHeight),
            ),
          ),
        ),
      ],
    );
  }
}

/// מה שצף מתחת לסמן בזמן גרירת שורה.
class _ToolDragFeedback extends StatelessWidget {
  final ToolCatalogEntry entry;

  const _ToolDragFeedback({required this.entry});

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
            entry.imageIcon != null
                ? ImageIcon(AssetImage(entry.imageIcon!), size: 18)
                : Icon(entry.icon, size: 18),
            const SizedBox(width: 8),
            Text(
              entry.label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// שורת כלי בעץ הניווט של הפאנל, בעיצוב שורות מסך הספרייה.
class ToolTile extends StatelessWidget {
  static const double menuButtonSize = 26;
  static const double menuIconSize = 15;

  final ToolCatalogEntry entry;
  final bool isOpen;
  final bool isHighlighted;
  final VoidCallback onTap;

  /// קצות הכרטיס המקובץ — כל קבוצה (כלים / תוספים) נראית ככרטיס אחד רציף.
  final bool isGroupStart;
  final bool isGroupEnd;

  /// פעולות תפריט ⋯. ריק = השורה מוצגת בלי כפתור פעולות.
  final List<ToolTileAction> actions;

  /// מזהה פעימת ההזזה: כל שינוי מריץ אנימציית הדגשה קצרה. 0 = ללא פעימה.
  final int movePulse;

  /// נקרא כשתפריט הפעולות נסגר — הפאנל מחזיר לעצמו את הפוקוס למקלדת.
  final VoidCallback? onMenuClosed;

  const ToolTile({
    super.key,
    required this.entry,
    required this.isOpen,
    required this.isHighlighted,
    required this.onTap,
    this.isGroupStart = true,
    this.isGroupEnd = true,
    this.actions = const [],
    this.movePulse = 0,
    this.onMenuClosed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _MovePulse(
      nonce: movePulse,
      child: NavTreeGroupCard(
        isGroupStart: isGroupStart,
        isGroupEnd: isGroupEnd,
        child: NavTreeTile.book(
          title: entry.label,
          level: 0,
          isSelected: isHighlighted,
          icon: entry.icon ?? FluentIcons.puzzle_piece_24_regular,
          leading: entry.imageIcon == null ? null : _buildImageLeading(context),
          trailing: _buildTrailing(cs),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildImageLeading(BuildContext context) => NavTreeTile.iconBox(
    context,
    child: ImageIcon(
      AssetImage(entry.imageIcon!),
      size: NavTreeTile.iconContentSize,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    ),
  );

  Widget _buildTrailing(ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOpen)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppTokens.spaceXS),
            child: Icon(
              FluentIcons.checkmark_circle_16_filled,
              size: 14,
              color: cs.primary,
            ),
          ),
        if (entry.isDevelopment)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppTokens.spaceXS),
            child: _Badge(label: 'DEV', color: cs.tertiary),
          ),
        if (actions.isNotEmpty) _buildMenuButton(cs),
      ],
    );
  }

  Widget _buildMenuButton(ColorScheme cs) {
    return SizedBox(
      width: menuButtonSize,
      height: menuButtonSize,
      child: AppPopupMenuButton<VoidCallback>(
        tooltip: 'אפשרויות נוספות',
        icon: Icon(
          FluentIcons.more_vertical_24_regular,
          size: menuIconSize,
          color: cs.secondary,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: menuButtonSize,
          minHeight: menuButtonSize,
        ),
        onSelected: (action) => action(),
        onMenuClosed: onMenuClosed,
        itemBuilder: (context) {
          final metrics =
              Theme.of(context).extension<AppMenuMetrics>() ??
              AppMenuMetrics.create(compactMenus: false);
          return [
            for (final action in actions) ...[
              if (action.dividerBefore) const PopupMenuDivider(),
              _menuItem(context, metrics, action),
            ],
          ];
        },
      ),
    );
  }

  PopupMenuEntry<VoidCallback> _menuItem(
    BuildContext context,
    AppMenuMetrics metrics,
    ToolTileAction action,
  ) {
    final children = action.children;
    // תת-תפריט שכל פעולותיו מושבתות מרונדר כשורה מעומעמת רגילה: שורת תת-תפריט
    // נפתחת בלחיצה על ה-InkWell הפנימי שלה גם כשהפריט מושבת.
    if (children != null && children.any((child) => child.onTap != null)) {
      return buildAppSubmenuPopupMenuItem<VoidCallback>(
        context: context,
        metrics: metrics,
        label: action.label,
        icon: action.icon,
        menuChildren: [
          for (final child in children) _menuItem(context, metrics, child),
        ],
        onSelected: (selected) => selected(),
      );
    }
    return buildAppPopupMenuItem<VoidCallback>(
      context,
      AppMenuEntry<VoidCallback>(
        value: action.onTap ?? () {},
        label: action.label,
        icon: action.icon,
        enabled: action.onTap != null,
        isDestructive: action.isDestructive,
      ),
      metrics,
      null,
    );
  }
}

/// פעימת הדגשה קצרה על שורה שזזה — מראה למשתמש לאן היא נחתה.
class _MovePulse extends StatefulWidget {
  final int nonce;
  final Widget child;

  const _MovePulse({required this.nonce, required this.child});

  @override
  State<_MovePulse> createState() => _MovePulseState();
}

class _MovePulseState extends State<_MovePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 320),
    vsync: this,
    value: 1.0,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void didUpdateWidget(covariant _MovePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nonce != oldWidget.nonce && widget.nonce != 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _progress,
      // מבנה העץ קבוע גם במנוחה: החלפת מבנה בתחילת הפעימה ובסופה הייתה בונה
      // את השורה מחדש ומאפסת את מצב הריחוף שלה.
      builder: (context, child) {
        final remaining = 1.0 - _progress.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppTokens.borderRadiusAll,
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.35 * remaining),
                blurRadius: 12 * remaining,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppTokens.borderRadiusAll,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onTertiary,
        ),
      ),
    );
  }
}
