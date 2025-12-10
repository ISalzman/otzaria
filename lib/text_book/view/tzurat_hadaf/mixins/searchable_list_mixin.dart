import 'package:flutter/material.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;

/// Mixin for adding search functionality to list-based widgets
mixin SearchableListMixin<T extends StatefulWidget> on State<T> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    searchController.addListener(onSearchChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  /// Called when search text changes
  void onSearchChanged() {
    setState(() {
      searchQuery = searchController.text;
      updateFilteredItems();
    });
  }

  /// Override this method to implement filtering logic
  void updateFilteredItems();

  /// Helper method to check if text matches search query
  bool matchesSearch(String text, String query) {
    if (query.isEmpty) return true;
    final searchableQuery = utils.removeVolwels(query.toLowerCase());
    final searchableText = utils.removeVolwels(text.toLowerCase());
    return searchableText.contains(searchableQuery);
  }
}
