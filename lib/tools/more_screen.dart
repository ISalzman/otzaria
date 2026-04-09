import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/personal_notes/view/personal_notes_screen.dart';
import 'package:otzaria/theme/theme_exports.dart';
import 'package:otzaria/tools/acronyms_dictionary/acronyms_dictionary_screen.dart';
import 'package:otzaria/tools/aramaic_dictionary/aramaic_dictionary_screen.dart';
import 'package:otzaria/tools/calendar/calendar_screen.dart';
import 'package:otzaria/tools/gematria/gematria_search_screen.dart';
import 'package:otzaria/tools/measurement_converter/measurement_converter_screen.dart';
import 'package:otzaria/tools/shamor_zachor/shamor_zachor.dart';
import 'package:otzaria/widgets/keyboard_navigator.dart';
import 'package:otzaria/widgets/rtl_icon.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  MoreScreenState createState() => MoreScreenState();
}

class MoreScreenState extends State<MoreScreen>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<CalendarWidgetState> _calendarKey =
      GlobalKey<CalendarWidgetState>();
  final ShamorZachorFocusController _shamorZachorFocusController =
      ShamorZachorFocusController();
  final GlobalKey _personalNotesKey = GlobalKey();
  final GlobalKey _measurementConverterKey = GlobalKey();
  final GlobalKey<GematriaSearchScreenState> _gematriaKey =
      GlobalKey<GematriaSearchScreenState>();
  final GlobalKey _aramaicDictionaryKey = GlobalKey();
  final GlobalKey _acronymsDictionaryKey = GlobalKey();
  final FocusNode _contentFocusNode = FocusNode(skipTraversal: true);
  final ScrollController _contentScrollController = ScrollController();
  late final List<Widget> _pages;

  int _selectedIndex = 0;
  bool _showMobileMenu = true;

  final List<_TabInfo> _tabs = const [
    _TabInfo(
      label: 'לוח שנה',
      icon: FluentIcons.calendar_24_regular,
      iconFilled: FluentIcons.calendar_24_filled,
    ),
    _TabInfo(
      label: 'שמור וזכור',
      imageIcon: 'assets/icon/שמור וזכור שחור ריק.png',
    ),
    _TabInfo(
      label: 'הערות אישיות',
      icon: FluentIcons.note_24_regular,
      iconFilled: FluentIcons.note_24_filled,
    ),
    _TabInfo(
      label: 'מדות ושיעורים',
      icon: FluentIcons.ruler_24_regular,
      iconFilled: FluentIcons.ruler_24_filled,
    ),
    _TabInfo(
      label: 'גימטריה',
      icon: FluentIcons.calculator_24_regular,
      iconFilled: FluentIcons.calculator_24_filled,
    ),
    _TabInfo(
      label: 'מילון ארמי-עברי',
      icon: FluentIcons.translate_24_regular,
      iconFilled: FluentIcons.translate_24_filled,
    ),
    _TabInfo(
      label: 'ראשי תיבות',
      icon: FluentIcons.text_quote_24_regular,
      iconFilled: FluentIcons.text_quote_24_filled,
    ),
  ];

  static const _mobileGroups = [
    (label: 'לוח שנה', indices: <int>[0]),
    (label: 'תורה שלמדתי', indices: <int>[1, 2]),
    (label: 'דקדוקי סופרים', indices: <int>[3, 4, 5, 6]),
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      BlocBuilder<CalendarCubit, CalendarState>(
        builder: (context, _) => CalendarWidget(key: _calendarKey),
      ),
      ShamorZachorWidget(
        focusController: _shamorZachorFocusController,
        onTitleChanged: (_) {},
      ),
      PersonalNotesManagerScreen(key: _personalNotesKey),
      MeasurementConverterScreen(key: _measurementConverterKey),
      GematriaSearchScreen(key: _gematriaKey),
      AramaicDictionaryScreen(key: _aramaicDictionaryKey),
      AcronymsDictionaryScreen(key: _acronymsDictionaryKey),
    ];
  }

  void _closeTransientPanelsForTab(int index) {
    switch (index) {
      case 0:
        _calendarKey.currentState?.closeTransientPanels();
        break;
      case 4:
        _gematriaKey.currentState?.closeTransientPanels();
        break;
    }
  }

  void closeTransientPanels() {
    _closeTransientPanelsForTab(_selectedIndex);
  }

  void _changeTab(int index) {
    if (_selectedIndex == index && !_showMobileMenu) {
      requestActiveTabFocus();
      return;
    }

    _closeTransientPanelsForTab(_selectedIndex);

    setState(() {
      _selectedIndex = index;
      _showMobileMenu = false;
    });
    requestActiveTabFocus();
  }

  void _requestDynamicKeyboardFocus(GlobalKey key) {
    final state = key.currentState;
    if (state != null) {
      (state as dynamic).requestKeyboardFocus();
    }
  }

  void requestActiveTabFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      if (_contentFocusNode.canRequestFocus) {
        _contentFocusNode.requestFocus();
      }

      switch (_selectedIndex) {
        case 0:
          _calendarKey.currentState?.requestKeyboardFocus();
          break;
        case 1:
          _shamorZachorFocusController.requestKeyboardFocus();
          break;
        case 2:
          _requestDynamicKeyboardFocus(_personalNotesKey);
          break;
        case 3:
          _requestDynamicKeyboardFocus(_measurementConverterKey);
          break;
        case 4:
          _gematriaKey.currentState?.requestKeyboardFocus();
          break;
        case 5:
          _requestDynamicKeyboardFocus(_aramaicDictionaryKey);
          break;
        case 6:
          _requestDynamicKeyboardFocus(_acronymsDictionaryKey);
          break;
      }
    });
  }

  void resetToCalendar() {
    setState(() {
      _selectedIndex = 0;
      _showMobileMenu = true;
    });
    requestActiveTabFocus();
  }

  @override
  void dispose() {
    _contentFocusNode.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildMobileMenu(Color bgColor) {
    final cs = Theme.of(context).colorScheme;
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
          for (final group in _mobileGroups) ...[
            _MobileGroupCard(
              title: group.label,
              children: [
                for (final idx in group.indices)
                  ListTile(
                    leading: _tabs[idx].imageIcon != null
                        ? ImageIcon(
                            AssetImage(_tabs[idx].imageIcon!),
                            size: 22,
                            color: cs.primary,
                          )
                        : Icon(_tabs[idx].icon, color: cs.primary),
                    title: Text(
                      _tabs[idx].label,
                      textDirection: TextDirection.rtl,
                    ),
                    trailing: const RtlIcon(Icons.chevron_left),
                    onTap: () => _changeTab(idx),
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
    return KeyboardNavigator(
      currentTabIndex: _selectedIndex,
      totalTabs: _tabs.length,
      onTabChange: _changeTab,
      onBack: () => setState(() => _showMobileMenu = true),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _tabs[_selectedIndex].label,
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
            child: _pages[_selectedIndex],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(Color bgColor) {
    return KeyboardNavigator(
      currentTabIndex: _selectedIndex,
      totalTabs: _tabs.length,
      onTabChange: _changeTab,
      onBack: null,
      child: ColoredBox(
        color: bgColor,
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent &&
                _contentScrollController.hasClients) {
              final newOffset =
                  _contentScrollController.offset + event.scrollDelta.dy;
              _contentScrollController.jumpTo(
                newOffset.clamp(
                  0.0,
                  _contentScrollController.position.maxScrollExtent,
                ),
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
                          for (int index = 0; index < _tabs.length; index++) ...[
                            _DesktopTopNavItem(
                              icon: _tabs[index].icon,
                              iconFilled: _tabs[index].iconFilled,
                              imageAsset: _tabs[index].imageIcon,
                              label: _tabs[index].label,
                              isSelected: _selectedIndex == index,
                              onTap: () => _changeTab(index),
                            ),
                            if (index < _tabs.length - 1)
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
                        child: IndexedStack(
                          sizing: StackFit.expand,
                          index: _selectedIndex,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isMoreScreenActive =
        context.select((NavigationBloc bloc) => bloc.state.currentScreen) ==
            Screen.more;

    if (isMoreScreenActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          requestActiveTabFocus();
        }
      });
    }

    final bgColor = AppSurfaces.panelBackground(context);

    return Theme(
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
                    ? 'mobile-${_showMobileMenu ? 'menu' : 'content-$_selectedIndex'}'
                    : 'desktop',
              ),
              child: content,
            ),
          );
        },
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

class _TabInfo {
  final String label;
  final IconData? icon;
  final IconData? iconFilled;
  final String? imageIcon;

  const _TabInfo({
    required this.label,
    this.icon,
    this.iconFilled,
    this.imageIcon,
  });
}
