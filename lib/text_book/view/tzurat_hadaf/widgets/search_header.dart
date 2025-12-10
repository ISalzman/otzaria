import 'package:flutter/material.dart';

/// Reusable search header widget with centered title and expandable search field
class SearchHeader extends StatefulWidget {
  final String title;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final double titleFontSize;

  const SearchHeader({
    super.key,
    required this.title,
    required this.searchController,
    required this.searchFocusNode,
    this.titleFontSize = 13,
  });

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    widget.searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.searchFocusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _isSearchFocused = widget.searchFocusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(128),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Title centered
          Center(
            child: Text(
              widget.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: widget.titleFontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Search at bottom left
          Positioned(
            bottom: -12,
            left: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSearchFocused ? 80 : 50,
              height: 24,
              child: TextField(
                controller: widget.searchController,
                focusNode: widget.searchFocusNode,
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'חיפוש',
                  hintStyle: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 0,
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
