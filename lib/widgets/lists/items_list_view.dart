import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/widgets/buttons/action_buttons.dart';
import 'package:otzaria/widgets/text/otzaria_search_field.dart';

class ItemsListView extends StatefulWidget {
  final List<dynamic> items;
  final Function(BuildContext, dynamic, int originalIndex) onItemTap;
  final Function(BuildContext, int originalIndex) onDelete;
  final Function(BuildContext) onClearAll;
  final String hintText;
  final String emptyText;
  final String notFoundText;
  final String clearAllText;
  final Widget? Function(dynamic item)? leadingIconBuilder;
  final String? Function(dynamic item)? subtitleBuilder;
  final String? Function(dynamic item)? subtitleTooltipBuilder;
  final String Function(dynamic item)? searchKeyBuilder;
  final bool Function(dynamic item)? additionalFilter;

  const ItemsListView({
    super.key,
    required this.items,
    required this.onItemTap,
    required this.onDelete,
    required this.onClearAll,
    required this.hintText,
    required this.emptyText,
    required this.notFoundText,
    required this.clearAllText,
    this.leadingIconBuilder,
    this.subtitleBuilder,
    this.subtitleTooltipBuilder,
    this.searchKeyBuilder,
    this.additionalFilter,
  });

  @override
  State<ItemsListView> createState() => _ItemsListViewState();
}

class _ItemsListViewState extends State<ItemsListView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  Widget _buildSubtitle(
    BuildContext context,
    String centerText,
    String? centerTooltip,
  ) {
    final cs = Theme.of(context).colorScheme;

    final subtitle = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        centerText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
        textDirection: TextDirection.rtl,
      ),
    );

    final tooltipMessage = centerTooltip?.trim();
    if (tooltipMessage == null || tooltipMessage.isEmpty) {
      return subtitle;
    }

    return Tooltip(
      message: tooltipMessage,
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 4),
      preferBelow: false,
      verticalOffset: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 360),
      textStyle: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: cs.onSurface,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: subtitle,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    // Auto-focus the search field when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          textDirection: TextDirection.rtl,
        ),
      );
    }

    // Filter items based on search query and additionalFilter
    final filteredItems = widget.items.where((item) {
      if (widget.additionalFilter != null && !widget.additionalFilter!(item)) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final searchText =
          widget.searchKeyBuilder?.call(item) ?? (item.ref as String);
      return searchText.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: OtzariaSearchField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: widget.hintText,
            onClear: () {
              setState(() {
                _searchQuery = '';
              });
            },
          ),
        ),
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Text(
                    widget.notFoundText,
                    textDirection: TextDirection.rtl,
                  ),
                )
              : ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final originalIndex = widget.items.indexOf(item);
                    final centerText = widget.subtitleBuilder?.call(item);
                    final centerTooltip =
                        widget.subtitleTooltipBuilder?.call(item);
                    return InkWell(
                      onTap: () =>
                          widget.onItemTap(context, item, originalIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            if (widget.leadingIconBuilder?.call(item) != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: widget.leadingIconBuilder!.call(item),
                              ),
                            Expanded(
                              child: Text(
                                item.ref,
                                style: const TextStyle(fontSize: 16),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                            if (centerText != null)
                              _buildSubtitle(
                                context,
                                centerText,
                                centerTooltip,
                              ),
                            IconButton(
                              icon: const Icon(FluentIcons.delete_24_regular),
                              tooltip: 'מחק',
                              onPressed: () =>
                                  widget.onDelete(context, originalIndex),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: NeutralActionButton(
            text: widget.clearAllText,
            onPressed: () => widget.onClearAll(context),
          ),
        ),
      ],
    );
  }
}
