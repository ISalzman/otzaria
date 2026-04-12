import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/focus_repository.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/personal_notes/view/personal_notes_screen.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/tools/measurement_converter/measurement_converter_screen.dart';
import 'package:otzaria/tools/gematria/gematria_search_screen.dart';
import 'package:otzaria/tools/acronyms_dictionary/acronyms_dictionary_screen.dart';
import 'package:otzaria/tools/aramaic_dictionary/aramaic_dictionary_screen.dart';
import 'package:otzaria/tools/shamor_zachor/shamor_zachor.dart';
import 'package:otzaria/tools/calendar/calendar_screen.dart';
import 'package:otzaria/widgets/keyboard_navigator.dart';
import 'package:otzaria/widgets/rtl_icon.dart';
import 'package:otzaria/widgets/custom_ui_components.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/view/plugin_side_panel.dart';
import 'package:otzaria/plugins/view/plugin_tab_page.dart';
import 'package:otzaria/plugins/view/plugin_install_screen.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';

abstract class ToolDescriptor {
  final String toolId;
  final String label;
  final int order;
  const ToolDescriptor({required this.toolId, required this.label, required this.order});
  Widget buildTab(BuildContext context);
  Widget buildPage(BuildContext context);
}

class BuiltInToolDescriptor extends ToolDescriptor {
  final IconData? icon;
  final IconData? iconFilled;
  final String? imageIcon;
  final Widget Function() pageBuilder;

  const BuiltInToolDescriptor({
    required super.toolId,
    required super.label,
    required super.order,
    this.icon,
    this.iconFilled,
    this.imageIcon,
    required this.pageBuilder,
  });

  @override
  Widget buildTab(BuildContext context) {
    if (imageIcon != null) {
      return SizedBox(
        width: 100,
        child: Tab(text: label, icon: ImageIcon(AssetImage(imageIcon!), size: 20)),
      );
    }
    return SizedBox(
      width: 100,
      child: Tab(text: label, icon: Icon(icon, size: 20)),
    );
  }

  @override
  Widget buildPage(BuildContext context) => pageBuilder();
}

class PluginToolDescriptor extends ToolDescriptor {
  final InstalledPlugin plugin;
  PluginToolDescriptor({required this.plugin})
      : super(
            toolId: plugin.pluginId,
            label: plugin.manifest.toolTabTitle,
            order: plugin.manifest.toolTabOrder);

  @override
  Widget buildTab(BuildContext context) {
    Widget? iconWidget;
    final codepoint = plugin.manifest.toolTabIconCodepoint;
    final fontFamily = plugin.manifest.toolTabIconFontFamily;
    if (codepoint != null && fontFamily != null) {
      iconWidget = Icon(
        IconData(
          codepoint,
          fontFamily: fontFamily,
          fontPackage: 'fluentui_system_icons',
        ),
        size: 20,
      );
    }
    return SizedBox(
      width: 100,
      child: Tab(
        text: label,
        icon: iconWidget,
      ),
    );
  }

  @override
  Widget buildPage(BuildContext context) => PluginTabPage(
        key: ValueKey(plugin.pluginId),
        plugin: plugin,
      );
}

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  MoreScreenState createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen> with AutomaticKeepAliveClientMixin {
  static const int _calendarFocusRetryCount = 6;

  final GlobalKey<CalendarWidgetState> _calendarKey = GlobalKey<CalendarWidgetState>();
  final GlobalKey<GematriaSearchScreenState> _gematriaKey = GlobalKey<GematriaSearchScreenState>();
  final FocusNode _contentFocusNode = FocusNode(skipTraversal: true);
  final ScrollController _contentScrollController = ScrollController();

  List<ToolDescriptor> _descriptors = [];
  List<Widget> _pages = [];
  String? _selectedToolId;
  bool _isPanelOpen = false;
  bool _showMobileMenu = true;
  InstalledPlugin? _transientPlugin;
  bool _didInitFromBloc = false;
  // מונע rebuild מרובה של הטאבים כאשר הזהות המלאה של הלשוניות לא השתנתה
  String _lastDescriptorsSignature = '';

  static const _mobileGroupDefs = [
    (label: 'לוח שנה', toolIds: <String>['builtin.calendar']),
    (label: 'תורה שלמדתי', toolIds: <String>['builtin.shamor_zachor', 'builtin.notes']),
    (label: 'דקדוקי סופרים', toolIds: <String>['builtin.measurements', 'builtin.gematria', 'builtin.aramaic_dictionary', 'builtin.acronyms_dictionary']),
  ];

  // ─── Focus management ────────────────────────────────────────────────────────

  String _descriptorSignature(List<ToolDescriptor> descriptors) {
    return descriptors.map((d) {
      if (d is PluginToolDescriptor) {
        return '${d.toolId}|${d.label}|${d.order}|${d.plugin.pinned}|${d.plugin.manifest.toolTabIconCodepoint}|${d.plugin.manifest.toolTabIconVariant}|${d.plugin.updatedAt.millisecondsSinceEpoch}';
      }
      return '${d.toolId}|${d.label}|${d.order}';
    }).join('::');
  }

  void _requestCalendarFocus({int remainingAttempts = _calendarFocusRetryCount}) {
    if (!mounted) return;
    final calendarState = _calendarKey.currentState;
    if (calendarState != null) {
      calendarState.requestKeyboardFocus();
      return;
    }
    if (remainingAttempts <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _requestCalendarFocus(remainingAttempts: remainingAttempts - 1);
        }
      });
    });
  }

  void requestActiveTabFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      if (_contentFocusNode.canRequestFocus) {
        _contentFocusNode.requestFocus();
      }
      if (_selectedToolId == 'builtin.calendar') {
        _requestCalendarFocus();
      }
    });
  }

  // ─── Tab / descriptor management ────────────────────────────────────────────

  List<ToolDescriptor> _buildBaseDescriptors() {
    return [
      BuiltInToolDescriptor(
        toolId: 'builtin.calendar',
        label: 'לוח שנה',
        icon: FluentIcons.calendar_24_regular,
        iconFilled: FluentIcons.calendar_24_filled,
        order: 10,
        pageBuilder: () => BlocBuilder<CalendarCubit, CalendarState>(
          builder: (context, _) => CalendarWidget(key: _calendarKey),
        ),
      ),
      BuiltInToolDescriptor(
        toolId: 'builtin.shamor_zachor',
        label: 'שמור וזכור',
        imageIcon: 'assets/icon/שמור וזכור שחור ריק.png',
        order: 20,
        pageBuilder: () => ShamorZachorWidget(onTitleChanged: (_) {}),
      ),
      BuiltInToolDescriptor(
        toolId: 'builtin.measurements',
        label: 'מדות ושיעורים',
        icon: FluentIcons.ruler_24_regular,
        iconFilled: FluentIcons.ruler_24_filled,
        order: 30,
        pageBuilder: () => const MeasurementConverterScreen(),
      ),
      BuiltInToolDescriptor(
        toolId: 'builtin.notes',
        label: 'הערות אישיות',
        icon: FluentIcons.note_24_regular,
        iconFilled: FluentIcons.note_24_filled,
        order: 40,
        pageBuilder: () => const PersonalNotesManagerScreen(),
      ),
      BuiltInToolDescriptor(
        toolId: 'builtin.gematria',
        label: 'גימטריה',
        icon: FluentIcons.calculator_24_regular,
        iconFilled: FluentIcons.calculator_24_filled,
        order: 50,
        pageBuilder: () => GematriaSearchScreen(key: _gematriaKey),
      ),
      BuiltInToolDescriptor(
        toolId: 'builtin.aramaic_dictionary',
        label: 'מילון ארמי-עברי',
        icon: FluentIcons.translate_24_regular,
        iconFilled: FluentIcons.translate_24_filled,
        order: 60,
        pageBuilder: () => const AramaicDictionaryScreen(),
      ),
      BuiltInToolDescriptor(
        toolId: 'builtin.acronyms_dictionary',
        label: 'ראשי תיבות',
        icon: FluentIcons.text_quote_24_regular,
        iconFilled: FluentIcons.text_quote_24_filled,
        order: 70,
        pageBuilder: () => const AcronymsDictionaryScreen(),
      ),
    ];
  }

  void _closeTransientPanelsForToolId(String? toolId) {
    // Reserved for future transient-panel teardown per tool
  }

  void closeTransientPanels() {
    _closeTransientPanelsForToolId(_selectedToolId);
  }

  void _changeTab(int index) {
    if (index < 0 || index >= _descriptors.length) return;
    final toolId = _descriptors[index].toolId;
    if (_selectedToolId == toolId && !_showMobileMenu) {
      requestActiveTabFocus();
      return;
    }
    _closeTransientPanelsForToolId(_selectedToolId);
    setState(() {
      _selectedToolId = toolId;
      _showMobileMenu = false;
    });
    requestActiveTabFocus();
  }

  void _openPluginTransiently(InstalledPlugin plugin) {
    if (plugin.pinned) {
      final index = _descriptors.indexWhere((d) => d.toolId == plugin.pluginId);
      if (index != -1) {
        _changeTab(index);
      }
      return;
    }
    // מגדיר את הפלאגין הזמני ומיד מבצע rebuild — ללא setState נפרד
    _transientPlugin = plugin;
    _selectedToolId = plugin.pluginId;
    final blocState = context.read<PluginSystemBloc>().state;
    if (blocState is PluginSystemLoaded) {
      _rebuildTabs(blocState.pinnedPlugins, transient: _transientPlugin);
    }
  }

  void _applyTabState(
    List<InstalledPlugin> pinnedPlugins, {
    InstalledPlugin? transient,
    required bool notify,
  }) {
    final newDescriptors = <ToolDescriptor>[
      ..._buildBaseDescriptors(),
      ...pinnedPlugins.map((p) => PluginToolDescriptor(plugin: p)),
    ];
    if (transient != null) {
      if (!pinnedPlugins.any((p) => p.pluginId == transient.pluginId)) {
        newDescriptors.add(PluginToolDescriptor(plugin: transient));
      }
    }

    newDescriptors.sort((a, b) => a.order.compareTo(b.order));
    final newSignature = _descriptorSignature(newDescriptors);
    if (newSignature == _lastDescriptorsSignature && _pages.isNotEmpty) {
      return;
    }
    _lastDescriptorsSignature = newSignature;

    String newToolId = _selectedToolId ?? newDescriptors.first.toolId;
    if (!newDescriptors.any((d) => d.toolId == newToolId)) {
      newToolId = newDescriptors.first.toolId;
    }

    void applyState() {
      _descriptors = newDescriptors;
      _pages = newDescriptors.map((t) => t.buildPage(context)).toList();
      _selectedToolId = newToolId;
    }

    if (notify) {
      setState(applyState);
    } else {
      applyState();
    }
  }

  void _rebuildTabs(List<InstalledPlugin> pinnedPlugins, {InstalledPlugin? transient}) {
    if (!mounted) return;
    _applyTabState(pinnedPlugins, transient: transient, notify: true);
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    FocusRepository().registerMoreScreenFocusRequester(requestActiveTabFocus);
    _applyTabState([], notify: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitFromBloc) {
      _didInitFromBloc = true;
      final state = context.read<PluginSystemBloc>().state;
      if (state is PluginSystemLoaded) {
        _applyTabState(state.pinnedPlugins, notify: false);
      }
    }
  }

  void resetToCalendar() {
    if (_selectedToolId != 'builtin.calendar') {
      setState(() {
        _selectedToolId = 'builtin.calendar';
        _showMobileMenu = false;
      });
      return;
    }
    _requestCalendarFocus();
  }

  @override
  void dispose() {
    FocusRepository().unregisterMoreScreenFocusRequester(requestActiveTabFocus);
    _contentFocusNode.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // ─── UI builders ─────────────────────────────────────────────────────────────

  Widget _buildMobileMenu(Color bgColor) {
    final cs = Theme.of(context).colorScheme;

    final groupedDescriptors = <({String label, List<ToolDescriptor> tools})>[];
    for (final group in _mobileGroupDefs) {
      final tools = [
        for (final id in group.toolIds) ..._descriptors.where((d) => d.toolId == id),
      ];
      if (tools.isNotEmpty) {
        groupedDescriptors.add((label: group.label, tools: tools));
      }
    }

    final groupedIds = _mobileGroupDefs.expand((g) => g.toolIds).toSet();
    final ungroupedPlugins = _descriptors.where((d) => !groupedIds.contains(d.toolId)).toList();
    if (ungroupedPlugins.isNotEmpty) {
      groupedDescriptors.add((label: 'תוספים', tools: ungroupedPlugins));
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('כלים', textDirection: TextDirection.rtl),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMD),
        children: [
          for (final group in groupedDescriptors) ...[
            _MobileGroupCard(
              title: group.label,
              children: [
                for (final descriptor in group.tools)
                  ListTile(
                    leading: descriptor is BuiltInToolDescriptor
                        ? (descriptor.imageIcon != null
                            ? ImageIcon(
                                AssetImage(descriptor.imageIcon!),
                                size: 22,
                                color: cs.primary,
                              )
                            : Icon(descriptor.icon, color: cs.primary))
                        : Icon(FluentIcons.puzzle_piece_24_regular, color: cs.primary),
                    title: Text(
                      descriptor.label,
                      textDirection: TextDirection.rtl,
                    ),
                    trailing: const RtlIcon(Icons.chevron_left),
                    onTap: () {
                      final index = _descriptors.indexOf(descriptor);
                      if (index != -1) _changeTab(index);
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSM),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileContent(Color bgColor) {
    final currentIndex = _descriptors.indexWhere((d) => d.toolId == _selectedToolId);
    final safeIndex = currentIndex.clamp(0, _descriptors.isEmpty ? 0 : _descriptors.length - 1);

    return KeyboardNavigator(
      currentTabIndex: safeIndex,
      totalTabs: _descriptors.length,
      onTabChange: _changeTab,
      onBack: () => setState(() => _showMobileMenu = true),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _descriptors.isEmpty ? '' : _descriptors[safeIndex].label,
            textDirection: TextDirection.rtl,
          ),
          leading: Tooltip(
            message: 'חזור (Backspace)',
            child: IconButton(
              icon: const RtlIcon(Icons.arrow_forward),
              onPressed: () => setState(() => _showMobileMenu = true),
            ),
          ),
        ),
        body: Focus(
          focusNode: _contentFocusNode,
          child: ColoredBox(
            color: bgColor,
            child: _pages.isEmpty ? const SizedBox() : _pages[safeIndex],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(Color bgColor) {
    final currentIndex = _descriptors.indexWhere((d) => d.toolId == _selectedToolId);
    final safeIndex = currentIndex.clamp(0, _descriptors.isEmpty ? 0 : _descriptors.length - 1);

    return KeyboardNavigator(
      currentTabIndex: safeIndex,
      totalTabs: _descriptors.length,
      onTabChange: _changeTab,
      onBack: null,
      child: ColoredBox(
        color: bgColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isPanelOpen)
              PluginSidePanel(
                onPluginSelected: (plugin) {
                  _openPluginTransiently(plugin);
                },
              ),
            Expanded(
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent && _contentScrollController.hasClients) {
                    final newOffset = _contentScrollController.offset + event.scrollDelta.dy;
                    _contentScrollController.jumpTo(
                      newOffset.clamp(0.0, _contentScrollController.position.maxScrollExtent),
                    );
                  }
                },
                child: Column(
                  children: [
                    ColoredBox(
                      color: bgColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.spaceXS,
                        ),
                        child: Row(
                          children: [
                            // מאזן שמאלי כדי שהטאבים יישארו ממורכזים
                            const SizedBox(width: 48),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int index = 0; index < _descriptors.length; index++) ...[
                                        _DesktopTopNavItem(
                                          icon: _descriptors[index] is BuiltInToolDescriptor
                                              ? (_descriptors[index] as BuiltInToolDescriptor).icon
                                              : FluentIcons.puzzle_piece_24_regular,
                                          iconFilled: _descriptors[index] is BuiltInToolDescriptor
                                              ? (_descriptors[index] as BuiltInToolDescriptor).iconFilled
                                              : FluentIcons.puzzle_piece_24_regular,
                                          imageAsset: _descriptors[index] is BuiltInToolDescriptor
                                              ? (_descriptors[index] as BuiltInToolDescriptor).imageIcon
                                              : null,
                                          label: _descriptors[index].label,
                                          isSelected: _selectedToolId == _descriptors[index].toolId,
                                          onTap: () => _changeTab(index),
                                        ),
                                        if (index < _descriptors.length - 1)
                                          const SizedBox(width: AppTokens.spaceXS),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // כפתור תוספים מוצמד לשמאל חזותי (סוף Row ב-RTL)
                            IconButton(
                              icon: const Icon(FluentIcons.puzzle_piece_24_regular),
                              onPressed: () =>
                                  setState(() => _isPanelOpen = !_isPanelOpen),
                              tooltip: 'תוספים',
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: PrimaryScrollController(
                          controller: _contentScrollController,
                          child: Focus(
                            focusNode: _contentFocusNode,
                            child: ColoredBox(
                              color: bgColor,
                              child: _pages.isEmpty
                                  ? const SizedBox()
                                  : IndexedStack(
                                      sizing: StackFit.expand,
                                      index: safeIndex,
                                      children: _pages,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMoreScreenActive =
        context.select((NavigationBloc bloc) => bloc.state.currentScreen) ==
            Screen.more;

    if (isMoreScreenActive && _selectedToolId == 'builtin.calendar') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) requestActiveTabFocus();
      });
    }

    final bgColor = AppSurfaces.panelBackground(context);

    return BlocListener<PluginSystemBloc, PluginSystemState>(
      listener: (context, state) {
        if (state is PluginSystemLoaded) {
          if (_transientPlugin != null) {
            final updatedTransient = state.plugins.firstWhere(
                (p) => p.pluginId == _transientPlugin!.pluginId,
                orElse: () => _transientPlugin!);
            _transientPlugin = updatedTransient;
          }
          _rebuildTabs(state.pinnedPlugins, transient: _transientPlugin);
        } else if (state is PluginSystemOverwriteRequired) {
          showWarningDialog(
            context: context,
            title: 'התוסף כבר קיים',
            content:
                'התוסף "${state.pluginName}" בגרסה ${state.version} כבר מותקן.',
            subtitle: 'האם ברצונך להתקין מחדש ולדרוס אותו?',
            cancelText: 'ביטול',
            confirmText: 'התקן מחדש',
          ).then((value) {
            if (!context.mounted) return;
            if (value == true) {
              context.read<PluginSystemBloc>().add(
                    InstallPluginRequested(state.archivePath,
                        forceOverwrite: true),
                  );
            } else {
              context.read<PluginSystemBloc>().add(LoadPlugins());
            }
          });
        } else if (state is PluginSystemInstallRequiresPermissions) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<PluginSystemBloc>(),
                child: PluginInstallScreen(
                  manifest: state.manifest,
                  tempDirPath: state.tempDirPath,
                ),
              ),
            ),
          );
        }
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: bgColor,
          canvasColor: bgColor,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < LayoutBreakpoints.compact;
            final content = isMobile
                ? (_showMobileMenu
                    ? _buildMobileMenu(bgColor)
                    : _buildMobileContent(bgColor))
                : _buildDesktop(bgColor);

            return AnimatedSwitcher(
              duration: AppTokens.animNormal,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                ),
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey(
                  isMobile
                      ? 'mobile-${_showMobileMenu ? 'menu' : 'content-$_selectedToolId'}'
                      : 'desktop',
                ),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DesktopTopNavItem extends StatelessWidget {
  final IconData? icon;
  final IconData? iconFilled;
  final String? imageAsset;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopTopNavItem({
    required this.icon,
    required this.iconFilled,
    required this.imageAsset,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = isSelected ? cs.onSecondaryContainer : cs.onSurfaceVariant;

    final iconWidget = imageAsset != null
        ? ImageIcon(AssetImage(imageAsset!), size: 20, color: fg)
        : Icon(
            isSelected && iconFilled != null ? iconFilled : icon,
            size: 20,
            color: fg,
          );

    return Material(
      color: isSelected ? cs.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return cs.primary.withValues(alpha: 0.08);
          }
          if (states.contains(WidgetState.pressed)) {
            return cs.primary.withValues(alpha: 0.12);
          }
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMD,
            vertical: AppTokens.spaceSM,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: AppTokens.spaceXS),
              Text(
                label,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: AppTokens.fontSM,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileGroupCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MobileGroupCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              textDirection: TextDirection.rtl,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
