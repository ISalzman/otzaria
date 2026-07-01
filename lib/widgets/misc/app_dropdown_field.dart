import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:otzaria/widgets/misc/app_popup_menu.dart';
import 'package:otzaria/widgets/misc/rtl_icon.dart';

class AppDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<AppMenuEntry<T>> entries;
  final ValueChanged<T?>? onSelected;
  final InputDecoration? decoration;
  final bool enabled;
  final bool isExpanded;
  final bool enableSearch;
  final Widget Function(BuildContext context, T? value)? selectedBuilder;
  final String Function(T value)? labelBuilder;
  final List<String>? filterLabels;
  final List<bool Function(AppMenuEntry<T>)?>? filterPredicates;
  final double? menuMinWidth;

  const AppDropdownField({
    super.key,
    required this.value,
    required this.entries,
    required this.onSelected,
    this.decoration,
    this.enabled = true,
    this.isExpanded = true,
    this.enableSearch = false,
    this.selectedBuilder,
    this.labelBuilder,
    this.filterLabels,
    this.filterPredicates,
    this.menuMinWidth,
  });

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  final GlobalKey _anchorKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String get _selectedLabel {
    if (widget.value == null) return '';
    for (final entry in widget.entries) {
      if (entry.value == widget.value) return entry.label;
    }
    if (widget.labelBuilder != null) {
      return widget.labelBuilder!(widget.value as T);
    }
    return '';
  }

  AppMenuEntry<T>? get _selectedEntry {
    if (widget.value == null) return null;
    for (final entry in widget.entries) {
      if (entry.value == widget.value) return entry;
    }
    return null;
  }

  Future<void> _openSelectionMenu() async {
    if (!widget.enabled ||
        widget.onSelected == null ||
        widget.entries.isEmpty) {
      return;
    }
    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null) return;

    final T? selected = widget.enableSearch
        ? await showAnchoredAppSearchMenu<T>(
            context: context,
            anchorContext: anchorContext,
            entries: widget.entries,
            initialValue: widget.value,
            searchHint: widget.decoration?.hintText ??
                widget.decoration?.labelText ??
                'חיפוש',
            filterLabels: widget.filterLabels,
            filterPredicates: widget.filterPredicates,
            menuMinWidth: widget.menuMinWidth,
          )
        : await showAnchoredAppMenu<T>(
            context: context,
            anchorContext: anchorContext,
            initialValue: widget.value,
            itemsBuilder: (metrics) => widget.entries
                .map<PopupMenuEntry<T>>(
                  (entry) => buildAppPopupMenuItem<T>(
                    context,
                    entry,
                    metrics,
                    widget.value,
                  ),
                )
                .toList(),
          );

    if (!mounted) return;
    // דחיית הפוקוס לפריים הבא — showMenu/push מחזירים Future לפני שאנימציית
    // הסגירה מסיימת; requestFocus() שמוקדם מדי מובס ע"י ה-FocusManager.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    if (selected != null) widget.onSelected?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = widget.enabled &&
        widget.onSelected != null &&
        widget.entries.isNotEmpty;

    final selectedEntry = _selectedEntry;
    final customLabelWidget =
        widget.selectedBuilder?.call(context, widget.value);

    return KeyedSubtree(
      key: _anchorKey,
      child: FilledButton.tonal(
        focusNode: _focusNode,
        onPressed: effectiveEnabled ? _openSelectionMenu : null,
        style: widget.isExpanded
            ? FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              )
            : null,
        child: Row(
          mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (selectedEntry?.icon != null) ...[
              RtlIcon(selectedEntry!.icon!),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: customLabelWidget ??
                  Text(
                    _selectedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
            const SizedBox(width: 8),
            Icon(FluentIcons.chevron_down_24_regular),
          ],
        ),
      ),
    );
  }
}
