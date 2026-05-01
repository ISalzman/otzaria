import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/theme/theme_exports.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AppMenuEntry — נתוני פריט בתפריט
// ═══════════════════════════════════════════════════════════════════════════

class AppMenuEntry<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
  final bool isDestructive;
  final Widget? trailing;

  const AppMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
    this.isDestructive = false,
    this.trailing,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// AppContextMenuEntry — פריט בתפריט הקשר (right-click)
// ═══════════════════════════════════════════════════════════════════════════

class AppContextMenuEntry {
  final Key? key;
  final String? label;
  final Widget? labelWidget;
  final IconData? icon;
  final bool enabled;
  final bool isDivider;
  final bool isDestructive;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// תת-פריטים לתפריט משנה
  final List<AppContextMenuEntry>? children;

  /// בנייה עצלה של תת-פריטים לתפריט משנה.
  final List<AppContextMenuEntry> Function()? childrenBuilder;

  const AppContextMenuEntry({
    required this.label,
    this.key,
    this.labelWidget,
    this.icon,
    this.enabled = true,
    this.isDestructive = false,
    this.onTap,
    this.trailing,
    this.children,
    this.childrenBuilder,
  }) : isDivider = false;

  const AppContextMenuEntry.divider()
      : key = null,
        label = null,
        labelWidget = null,
        icon = null,
        enabled = false,
        isDivider = true,
        isDestructive = false,
        onTap = null,
        trailing = null,
        children = null,
        childrenBuilder = null;
}

bool hasEnabledAppContextMenuEntries(List<AppContextMenuEntry> entries) {
  return entries.any((entry) => !entry.isDivider);
}

// ═══════════════════════════════════════════════════════════════════════════
// AppPopupMenuButton — כפתור שפותח תפריט
// ═══════════════════════════════════════════════════════════════════════════

class AppPopupMenuButton<T> extends StatefulWidget {
  final List<AppMenuEntry<T>>? entries;
  final List<PopupMenuEntry<T>> Function(BuildContext context)? itemBuilder;
  final ValueChanged<T>? onSelected;
  final Widget? child;
  final Widget? icon;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final PopupMenuPosition position;
  final Offset offset;
  final bool enabled;
  final T? initialValue;

  const AppPopupMenuButton({
    super.key,
    this.entries,
    this.itemBuilder,
    this.onSelected,
    this.child,
    this.icon,
    this.tooltip,
    this.padding,
    this.constraints,
    this.position = PopupMenuPosition.under,
    this.offset = const Offset(0, 4),
    this.enabled = true,
    this.initialValue,
  });

  @override
  State<AppPopupMenuButton<T>> createState() => _AppPopupMenuButtonState<T>();
}

class _AppPopupMenuButtonState<T> extends State<AppPopupMenuButton<T>> {
  final GlobalKey _anchorKey = GlobalKey();

  bool get _isTouchMode {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  bool get _hasCompactConstraints {
    final constraints = widget.constraints;
    if (constraints == null) return false;
    final minWidth = constraints.minWidth;
    final maxWidth = constraints.maxWidth;
    final minHeight = constraints.minHeight;
    final maxHeight = constraints.maxHeight;
    final width = minWidth > 0 ? minWidth : maxWidth;
    final height = minHeight > 0 ? minHeight : maxHeight;
    return width > 0 && width <= 40 && height > 0 && height <= 40;
  }

  List<PopupMenuEntry<T>> _buildItems(
    BuildContext context,
    AppMenuMetrics metrics,
  ) {
    return widget.itemBuilder?.call(context) ??
        widget.entries!
            .map<PopupMenuEntry<T>>(
              (entry) => buildAppPopupMenuItem<T>(
                context,
                entry,
                metrics,
                widget.initialValue,
              ),
            )
            .toList();
  }

  Future<void> _showAdaptiveMenu() async {
    if (!widget.enabled) return;
    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null) return;

    final selected = await showAnchoredAppMenu<T>(
      context: context,
      anchorContext: anchorContext,
      itemsBuilder: (metrics) => _buildItems(context, metrics),
      position: widget.position,
      offset: widget.offset,
    );

    if (selected != null) {
      widget.onSelected?.call(selected);
    }
  }

  Future<void> showMenu() => _showAdaptiveMenu();

  @override
  Widget build(BuildContext context) {
    assert(widget.entries != null || widget.itemBuilder != null);

    Widget trigger;
    if (widget.child != null) {
      trigger = InkWell(
        onTap: widget.enabled ? _showAdaptiveMenu : null,
        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
        child: widget.child,
      );
    } else if (_isTouchMode &&
        widget.tooltip != null &&
        !_hasCompactConstraints) {
      trigger = TextButton.icon(
        onPressed: widget.enabled ? _showAdaptiveMenu : null,
        icon: widget.icon ?? const Icon(FluentIcons.more_vertical_24_regular),
        label: Text(
          widget.tooltip!,
          textDirection: TextDirection.rtl,
        ),
      );
    } else {
      trigger = IconButton(
        onPressed: widget.enabled ? _showAdaptiveMenu : null,
        padding: widget.padding ?? EdgeInsets.zero,
        constraints: widget.constraints,
        tooltip: widget.tooltip,
        icon: widget.icon ?? const Icon(FluentIcons.more_vertical_24_regular),
      );
    }

    if (widget.child == null &&
        widget.constraints != null &&
        trigger is! IconButton) {
      trigger = ConstrainedBox(
        constraints: widget.constraints!,
        child: Center(child: trigger),
      );
    }

    return KeyedSubtree(
      key: _anchorKey,
      child: trigger,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// showAnchoredAppMenu — פתיחת תפריט עוגן לרכיב קיים
// ═══════════════════════════════════════════════════════════════════════════

Future<T?> showAnchoredAppMenu<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<PopupMenuEntry<T>> Function(AppMenuMetrics metrics)
      itemsBuilder,
  PopupMenuPosition position = PopupMenuPosition.under,
  Offset offset = const Offset(0, 4),
}) async {
  final metrics = Theme.of(context).extension<AppMenuMetrics>() ??
      AppMenuMetrics.create(compactMenus: false);
  final items = itemsBuilder(metrics);
  if (items.isEmpty) return null;

  final renderBox = anchorContext.findRenderObject() as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final targetRect = MatrixUtils.transformRect(
    renderBox.getTransformTo(overlay),
    Offset.zero & renderBox.size,
  );

  final menuHeight = items.fold<double>(
        metrics.menuPadding.vertical,
        (sum, item) => sum + item.height,
      ) +
      8;
  final spaceAbove = targetRect.top;
  final spaceBelow = overlay.size.height - targetRect.bottom;
  final preferBelow = position == PopupMenuPosition.under;
  final shouldOpenBelow = preferBelow
      ? (spaceBelow >= menuHeight || spaceBelow >= spaceAbove)
      : !(spaceAbove >= menuHeight || spaceAbove >= spaceBelow);

  final anchorTop = shouldOpenBelow
      ? targetRect.bottom + offset.dy
      : (targetRect.top - menuHeight - offset.dy).clamp(
          0.0,
          overlay.size.height,
        );

  final anchorRect = RelativeRect.fromRect(
    Rect.fromLTWH(targetRect.left, anchorTop, targetRect.width, 0),
    Offset.zero & overlay.size,
  );

  return showMenu<T>(
    context: context,
    position: anchorRect,
    items: items,
    // מינימום רוחב תואם רוחב הטריגר — סעיף 4
    constraints: BoxConstraints(minWidth: targetRect.width),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// buildAppMenuRowContent — בניית שורת תוכן בתפריט
//
// שינויים:
// • הרקע הנבחר ממלא שורה שלמה (ללא borderRadius, ללא גבול)
// • סימן ✓ תמיד מופיע לפריט נבחר
// ═══════════════════════════════════════════════════════════════════════════

Widget buildAppMenuRowContent(
  BuildContext context,
  AppMenuMetrics metrics, {
  required String label,
  double? maxWidth,
  Widget? labelWidget,
  IconData? icon,
  Widget? trailing,
  bool isSelected = false,
  bool isDestructive = false,
  bool enabled = true,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  // M3: selectedContainer = primaryContainer (ללא גבול, ממלא שורה שלמה)
  final selectedBackground =
      colorScheme.primaryContainer.withValues(alpha: 0.95);
  final foregroundColor = !enabled
      ? colorScheme.onSurface.withValues(alpha: 0.38)
      : isDestructive
          ? colorScheme.error
          : isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface;

  final hasTrailingWidget = isSelected || trailing != null;
  final labelMaxWidth = calculateAppMenuLabelMaxWidth(
    metrics,
    maxWidth: maxWidth,
    hasLeadingIcon: icon != null,
    hasTrailingWidget: hasTrailingWidget,
  );
  final labelTextStyle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: metrics.fontSize,
    fontWeight: isSelected ? FontWeight.w600 : metrics.itemFontWeight,
    color: foregroundColor,
  );
  final labelChild = labelWidget ??
      Text(
        label,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        textDirection: TextDirection.rtl,
      );

  final row = Row(
    mainAxisSize: trailing != null ? MainAxisSize.max : MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: metrics.iconSize, color: foregroundColor),
        const SizedBox(width: 8),
      ],
      Directionality(
        textDirection: TextDirection.rtl,
        child: DefaultTextStyle.merge(
          style: labelTextStyle,
          child: labelMaxWidth == null
              ? labelChild
              : ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: labelMaxWidth),
                  child: labelChild,
                ),
        ),
      ),
      // סימן ✓ לפריט נבחר (תמיד, בכל סוג תפריט)
      if (isSelected) ...[
        const SizedBox(width: 8),
        Icon(
          FluentIcons.checkmark_24_regular,
          size: metrics.iconSize,
          color: foregroundColor,
        ),
      ] else if (trailing != null) ...[
        const Spacer(),
        IconTheme.merge(
          data: IconThemeData(
            size: metrics.iconSize,
            color: foregroundColor,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foregroundColor),
            child: trailing,
          ),
        ),
      ],
    ],
  );

  return Container(
    constraints: BoxConstraints(
      minWidth: metrics.menuMinWidth,
      minHeight: metrics.itemHeight,
    ),
    // צבע מלא שורה — ללא עיגול פינות וללא גבול
    color: isSelected ? selectedBackground : null,
    padding: metrics.itemPadding,
    alignment: AlignmentDirectional.centerStart,
    child: row,
  );
}

double? calculateAppMenuLabelMaxWidth(
  AppMenuMetrics metrics, {
  required double? maxWidth,
  required bool hasLeadingIcon,
  required bool hasTrailingWidget,
}) {
  if (maxWidth == null) return null;

  final occupiedWidth = metrics.itemPadding.horizontal +
      (hasLeadingIcon ? metrics.iconSize + 8 : 0) +
      (hasTrailingWidget ? metrics.iconSize + 8 : 0);
  final availableWidth = maxWidth - occupiedWidth;
  if (availableWidth <= 0) return null;

  return availableWidth;
}

// ═══════════════════════════════════════════════════════════════════════════
// buildAppPopupMenuItem
// ═══════════════════════════════════════════════════════════════════════════

PopupMenuEntry<T> buildAppPopupMenuItem<T>(BuildContext context,
    AppMenuEntry<T> entry, AppMenuMetrics metrics, T? selectedValue,
    {Key? key}) {
  final isSelected = selectedValue != null && entry.value == selectedValue;

  return PopupMenuItem<T>(
    key: key,
    value: entry.value,
    enabled: entry.enabled,
    height: metrics.itemHeight,
    // padding: EdgeInsets.zero — הריפוד מנוהל ב-buildAppMenuRowContent
    // כדי שהצבע הנבחר יכסה שורה שלמה
    padding: EdgeInsets.zero,
    child: buildAppMenuRowContent(
      context,
      metrics,
      label: entry.label,
      icon: entry.icon,
      trailing: entry.trailing,
      isSelected: isSelected,
      isDestructive: entry.isDestructive,
      enabled: entry.enabled,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// buildAppCustomPopupMenuItem
// ═══════════════════════════════════════════════════════════════════════════

PopupMenuEntry<T> buildAppCustomPopupMenuItem<T>({
  required BuildContext context,
  required AppMenuMetrics metrics,
  required Widget child,
  bool enabled = false,
  double? height,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return PopupMenuItem<T>(
    enabled: enabled,
    height: height ?? metrics.itemHeight,
    padding: padding,
    child: child,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// buildAppSubmenuItemStyle
// ═══════════════════════════════════════════════════════════════════════════

ButtonStyle buildAppSubmenuItemStyle(
  BuildContext context,
  AppMenuMetrics metrics,
) {
  final colorScheme = Theme.of(context).colorScheme;
  return ButtonStyle(
    padding: WidgetStatePropertyAll(metrics.itemPadding),
    minimumSize:
        WidgetStatePropertyAll(Size(metrics.menuMinWidth, metrics.itemHeight)),
    visualDensity: metrics.visualDensity,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.itemBorderRadius),
      ),
    ),
    alignment: Alignment.centerRight,
    textStyle: WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Roboto',
        fontSize: metrics.fontSize,
        fontWeight: metrics.itemFontWeight,
      ),
    ),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withValues(alpha: 0.38);
      }
      return colorScheme.onSurface;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withValues(alpha: 0.38);
      }
      return colorScheme.onSurface;
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colorScheme.onSurface.withValues(alpha: 0.08);
      }
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.onSurface.withValues(alpha: 0.12);
      }
      return null;
    }),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// buildAppSubmenuPopupMenuItem
// ═══════════════════════════════════════════════════════════════════════════

PopupMenuEntry<T> buildAppSubmenuPopupMenuItem<T>({
  required BuildContext context,
  required AppMenuMetrics metrics,
  required String label,
  IconData? icon,
  required List<Widget> menuChildren,
}) {
  return buildAppCustomPopupMenuItem<T>(
    context: context,
    metrics: metrics,
    child: SubmenuButton(
      menuChildren: menuChildren,
      style: buildAppSubmenuItemStyle(context, metrics),
      child: buildAppMenuRowContent(
        context,
        metrics,
        label: label,
        icon: icon,
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// showAppMenu — הצגת תפריט במיקום מוחלט
// ═══════════════════════════════════════════════════════════════════════════

Future<T?> showAppMenu<T>({
  required BuildContext context,
  required RelativeRect position,
  required List<AppMenuEntry<T>> entries,
}) {
  final metrics = Theme.of(context).extension<AppMenuMetrics>() ??
      AppMenuMetrics.create(compactMenus: false);
  return showMenu<T>(
    context: context,
    position: position,
    items: entries
        .map<PopupMenuEntry<T>>(
          (entry) => buildAppPopupMenuItem<T>(context, entry, metrics, null),
        )
        .toList(),
  );
}

