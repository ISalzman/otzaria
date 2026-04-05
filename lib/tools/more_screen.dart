import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:otzaria/tools/calendar/ulits/calendar_widget.dart';
import 'package:otzaria/tools/calendar/ulits/calendar_cubit.dart';
import 'package:otzaria/widgets/keyboard_navigator.dart';
import 'package:otzaria/widgets/rtl_icon.dart';
import 'package:otzaria/widgets/custom_ui_components.dart';
import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/view/plugin_side_panel.dart';
import 'package:otzaria/plugins/view/plugin_tab_page.dart';
import 'package:otzaria/plugins/view/plugin_test_screen.dart';
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
  final bool isTransient;
  PluginToolDescriptor({required this.plugin, this.isTransient = false})
      : super(toolId: plugin.pluginId, label: plugin.manifest.toolTabTitle, order: plugin.manifest.toolTabOrder);

  @override
  Widget buildTab(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Tab(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.puzzle_piece_24_regular, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: isTransient ? const TextStyle(fontStyle: FontStyle.italic) : null,
              ),
            ),
          ],
        ),
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

  static const _mobileGroupDefs = [
    (label: 'לוח שנה', toolIds: <String>['builtin.calendar']),
    (label: 'תורה שלמדתי', toolIds: <String>['builtin.shamor_zachor', 'builtin.notes']),
    (label: 'דקדוקי סופרים', toolIds: <String>['builtin.measurements', 'builtin.gematria', 'builtin.aramaic_dictionary', 'builtin.acronyms_dictionary']),
  ];

  // ─── Focus management ────────────────────────────────────────────────────────

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
        if (mounted) _requestCalendarFocus(remainingAttempts: remainingAttempts - 1);
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
      if (kDebugMode)
        BuiltInToolDescriptor(
          toolId: 'builtin.plugin_test',
          label: 'Plugin POC (Debug)',
          icon: FluentIcons.bug_24_regular,
          order: 999,
          pageBuilder: () => const PluginTestScreen(),
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
    _transientPlugin = plugin;
    _selectedToolId = plugin.pluginId;
    final blocState = context.read<PluginSystemBloc>().state;
    if (blocState is PluginSystemLoaded) {
      _rebuildTabs(blocState.pinnedPlugins, transient: _transientPlugin);
    } else {
      setState(() {});
    }
  }

  void _rebuildTabs(List<InstalledPlugin> pinnedPlugins, {InstalledPlugin? transient}) {
    if (!mounted) return;

    final newDescriptors = <ToolDescriptor>[
      ..._buildBaseDescriptors(),
      ...pinnedPlugins.map((p) => PluginToolDescriptor(plugin: p)),
    ];
    if (transient != null) {
      if (!pinnedPlugins.any((p) => p.pluginId == transient.pluginId)) {
        newDescriptors.add(PluginToolDescriptor(plugin: transient, isTransient: true));
      }
    }
    newDescriptors.sort((a, b) => a.order.compareTo(b.order));

    String newToolId = _selectedToolId ?? newDescriptors.first.toolId;
    if (!newDescriptors.any((d) => d.toolId == newToolId)) {
      newToolId = newDescriptors.first.toolId;
    }

    setState(() {
      _descriptors = newDescriptors;
      _pages = newDescriptors.map((t) => t.buildPage(context)).toList();
      _selectedToolId = newToolId;
    });
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    FocusRepository().registerMoreScreenFocusRequester(requestActiveTabFocus);
    _rebuildTabs([]);
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
                        padding: const EdgeInsets.only(
                          top: AppTokens.spaceXS,
                          bottom: AppTokens.spaceXS,
                          right: AppTokens.spaceMD,
                          left: AppTokens.spaceMD,
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(FluentIcons.puzzle_piece_24_regular),
                                  onPressed: () => setState(() => _isPanelOpen = !_isPanelOpen),
                                  tooltip: 'תוספים',
                                ),
                                const SizedBox(width: AppTokens.spaceXS),
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
        context.select((NavigationBloc bloc) => bloc.state.currentScreen) == Screen.more;

    if (isMoreScreenActive && _selectedToolId == 'builtin.calendar') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) requestActiveTabFocus();
      });
    }

    final bgColor = AppSurfaces.panelBackground(context);

    return BlocListener<PluginSystemBloc, PluginSystemState>(
      listener: (context, state) {
        if (state is PluginSystemLoaded) {
          _rebuildTabs(state.pinnedPlugins, transient: _transientPlugin);
        } else if (state is PluginSystemOverwriteRequired) {
          showWarningDialog(
            context: context,
            title: 'התוסף כבר קיים',
            content: 'התוסף "${state.pluginName}" בגרסה ${state.version} כבר מותקן.',
            subtitle: 'האם ברצונך להתקין מחדש ולדרוס אותו?',
            cancelText: 'ביטול',
            confirmText: 'התקן מחדש',
          ).then((value) {
            if (!context.mounted) return;
            if (value == true) {
              context.read<PluginSystemBloc>().add(
                    InstallPluginRequested(state.archivePath, forceOverwrite: true),
                  );
            } else {
              context.read<PluginSystemBloc>().add(LoadPlugins());
            }
          });
        } else if (state is PluginSystemInstallRequiresPermissions) {
          final permList = state.manifest.permissions.isEmpty 
              ? 'אין הרשאות מיוחדות נדרשות'
              : state.manifest.permissions.join('\n');
          showWarningDialog(
            context: context,
            title: 'אישור התקנת תוסף',
            content: 'התוסף "${state.manifest.name}" מבקש גישה למשאבי מערכת.\n\nהרשאות נדרשות:\n$permList',
            subtitle: 'האם ברצונך לאשר הרשאות אלו ולהתקין את התוסף?',
            cancelText: 'ביטול',
            confirmText: 'התקן וקבל',
          ).then((value) {
            if (!context.mounted) return;
            if (value == true) {
              context.read<PluginSystemBloc>().add(ConfirmPluginInstall(state.tempDirPath, state.manifest));
            } else {
              context.read<PluginSystemBloc>().add(CancelPluginInstall(state.tempDirPath));
            }
          });
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
                ? (_showMobileMenu ? _buildMobileMenu(bgColor) : _buildMobileContent(bgColor))
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
