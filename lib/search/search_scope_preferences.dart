import 'dart:convert';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';

class SearchScopePreferencesData {
  final bool searchAllCategories;
  final Set<String> manualFacets;

  const SearchScopePreferencesData({
    required this.searchAllCategories,
    required this.manualFacets,
  });
}

class SearchScopePreferences {
  static const String _searchAllKey = 'key-search-all-categories-enabled';
  static const String _manualFacetsKey = 'key-search-manual-category-facets';

  SearchScopePreferences._();

  static SearchScopePreferencesData load() {
    final searchAll = Settings.getValue<bool>(_searchAllKey) ?? true;
    final rawManualFacets = Settings.getValue<String>(_manualFacetsKey);

    if (rawManualFacets == null || rawManualFacets.trim().isEmpty) {
      return _canonicalize(
        searchAllCategories: searchAll,
        manualFacets: const {},
      );
    }

    try {
      final decoded = jsonDecode(rawManualFacets);
      if (decoded is! List) {
        return _canonicalize(
          searchAllCategories: searchAll,
          manualFacets: const {},
        );
      }

      final facets = decoded
          .whereType<String>()
          .map(_normalizeFacet)
          .where((facet) => facet.isNotEmpty && facet != '/')
          .toSet();

      return _canonicalize(
        searchAllCategories: searchAll,
        manualFacets: facets,
      );
    } catch (_) {
      return const SearchScopePreferencesData(
        searchAllCategories: true,
        manualFacets: {},
      );
    }
  }

  static Future<void> save({
    required bool searchAllCategories,
    required Set<String> manualFacets,
  }) async {
    final normalized = manualFacets
        .map(_normalizeFacet)
        .where((facet) => facet.isNotEmpty && facet != '/')
        .toList()
      ..sort();

    final canonicalized = _canonicalize(
      searchAllCategories: searchAllCategories,
      manualFacets: normalized.toSet(),
    );

    await Settings.setValue<bool>(
      _searchAllKey,
      canonicalized.searchAllCategories,
    );
    await Settings.setValue<String>(
      _manualFacetsKey,
      jsonEncode(canonicalized.manualFacets.toList()..sort()),
    );
  }

  static SearchScopePreferencesData _canonicalize({
    required bool searchAllCategories,
    required Set<String> manualFacets,
  }) {
    if (!searchAllCategories && manualFacets.isEmpty) {
      return const SearchScopePreferencesData(
        searchAllCategories: true,
        manualFacets: {},
      );
    }

    return SearchScopePreferencesData(
      searchAllCategories: searchAllCategories,
      manualFacets: manualFacets,
    );
  }

  static String _normalizeFacet(String facet) {
    final trimmed = facet.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final normalized = trimmed.replaceAll(RegExp(r'/+'), '/');
    if (normalized == '/') {
      return '/';
    }

    return normalized.startsWith('/') ? normalized : '/$normalized';
  }
}
