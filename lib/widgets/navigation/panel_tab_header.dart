import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/theme/app_surfaces.dart';
import 'package:otzaria/theme/app_tokens.dart';

/// טאב סטנדרטי לפנלים הימניים (ללא אייקון filled).
/// כאשר [label] הוא null — מוצג אייקון בלבד (מצב compact).
class PanelTab extends StatelessWidget {
  final IconData icon;
  final String? label;

  const PanelTab({super.key, required this.icon, this.label});

  @override
  Widget build(BuildContext context) {
    final lbl = label;
    if (lbl == null) {
      return Tab(
        icon: Icon(icon, size: AppTokens.panelTabIconSize),
        height: AppTokens.panelTabHeight,
      );
    }
    return Tab(
      icon: Icon(icon, size: AppTokens.panelTabIconSize),
      iconMargin: AppTokens.panelTabIconMargin,
      height: AppTokens.panelTabHeight,
      child: Text(
        lbl,
        style: const TextStyle(fontSize: AppTokens.panelTabFontSize),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// כפתור "פתח פאנל" — רצועה מונפשת בשולי המסך שמתרחבת עם hover.
class PanelOpenHandle extends StatefulWidget {
  final VoidCallback onTap;

  const PanelOpenHandle({super.key, required this.onTap});

  @override
  State<PanelOpenHandle> createState() => _PanelOpenHandleState();
}

class _PanelOpenHandleState extends State<PanelOpenHandle> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: _isHovering ? 48 : 20,
          height: 80,
          decoration: BoxDecoration(
            color: AppSurfaces.panelOpenHandle(cs, isHovering: _isHovering),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: _isHovering ? 8 : 4,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _isHovering ? 1.0 : 0.6,
              child: Icon(
                FluentIcons.chevron_right_24_regular,
                size: _isHovering ? 24 : 18,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header לפנלים הימניים — טאב בר וכפתור סגירה.
class PanelTabHeader extends StatelessWidget {
  final TabController controller;
  final List<Widget> tabs;
  final VoidCallback? onClose;
  final ValueChanged<int>? onTap;
  final List<Widget> extraActions;

  const PanelTabHeader({
    super.key,
    required this.controller,
    required this.tabs,
    this.onClose,
    this.onTap,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTokens.panelTabHeight,
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: controller,
              tabs: tabs,
              splashBorderRadius: AppTokens.borderRadiusAll,
              onTap: onTap,
            ),
          ),
          ...extraActions,
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(FluentIcons.dismiss_24_regular),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
