import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:logging/logging.dart';

import '../models/book_model.dart';
import '../models/error_model.dart';

/// Service for loading book data from JSON assets
class DataLoaderService {
  static final Logger _logger = Logger('DataLoaderService');

  Map<String, BookCategory>? _cachedData;
  final String _assetsBasePath;

  DataLoaderService({String? assetsBasePath})
      : _assetsBasePath =
            assetsBasePath ?? 'packages/shamor_zachor/assets/data/';

  /// Clear the cached data
  void clearCache() {
    _cachedData = null;
  }

  /// Load all book categories from JSON files
  Future<Map<String, BookCategory>> loadData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    try {
      // --- אבחון באמצעות PRINT ---
      debugPrint("--- STARTING ASSET DIAGNOSTICS WITH PRINT() ---");
      debugPrint("Searching for assets with base path: '$_assetsBasePath'");

      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // --- הדפסת כל המפתחות הרלוונטיים מהמניפסט ---
      final relevantKeys = manifestMap.keys
          .where((key) => key.toString().contains('shamor_zachor'))
          .toList();
      debugPrint(
          "All keys in AssetManifest.json containing 'shamor_zachor': $relevantKeys");

      final List<String> jsonFilesPaths = manifestMap.keys
          .where((String key) =>
              key.startsWith(_assetsBasePath) && key.endsWith('.json'))
          .toList();

      // --- הדפסת הנתיבים שנמצאו לאחר סינון ---
      debugPrint(
          "Filtered paths (the files we actually found): $jsonFilesPaths");

      if (jsonFilesPaths.isEmpty) {
        debugPrint(
            "CRITICAL: No JSON files were found using the path '$_assetsBasePath'.");
        // הדפסת כל המפתחות כדי שנוכל לראות מה באמת קיים
        debugPrint(
            "Full list of available keys in manifest: ${manifestMap.keys.toList()}");
        throw ShamorZachorError(
          type: ShamorZachorErrorType.missingAsset,
          message:
              'No JSON data files found in $_assetsBasePath. Please check the console output for available keys.',
        );
      }

      Map<String, BookCategory> combinedData = {};

      for (String path in jsonFilesPaths) {
        try {
          final category = await _loadCategoryFromFile(path);
          if (category != null) {
            combinedData[category.name] = category;
          }
        } catch (e, stackTrace) {
          debugPrint('Error loading category from $path: $e\n$stackTrace');
        }
      }

      if (combinedData.isEmpty) {
        throw ShamorZachorError(
          type: ShamorZachorErrorType.parseError,
          message: 'No valid categories could be loaded',
        );
      }

      _cachedData = combinedData;
      debugPrint("--- ASSET DIAGNOSTICS COMPLETE ---");
      debugPrint("Successfully loaded ${combinedData.length} categories");
      return combinedData;
    } catch (e, stackTrace) {
      if (e is ShamorZachorError) {
        rethrow;
      }
      throw ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to load book data',
      );
    }
  }

  /// Load a single category from a JSON file
  Future<BookCategory?> _loadCategoryFromFile(String path) async {
    try {
      final String jsonString = await rootBundle.loadString(path);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      // Validate required fields
      if (!_isValidCategoryJson(jsonData)) {
        _logger.warning('Invalid JSON structure in $path');
        return null;
      }

      // Check schema version for future migrations
      final schemaVersion = jsonData['schemaVersion'] as int? ?? 1;
      if (schemaVersion > 1) {
        _logger.warning('Unsupported schema version $schemaVersion in $path');
        // For now, try to load anyway, but log the warning
      }

      String fileName = p.basename(path);
      return BookCategory.fromJson(jsonData, fileName);
    } catch (e, stackTrace) {
      throw ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        type: ShamorZachorErrorType.parseError,
        customMessage: 'Failed to parse $path',
      );
    }
  }

  bool _isValidCategoryJson(Map<String, dynamic> json) {
    // Check required fields
    if (json['name'] == null || json['name'] is! String) {
      return false;
    }
    if (json['content_type'] == null || json['content_type'] is! String) {
      return false;
    }

    // Must have at least one of: data, books, or subcategories
    final hasData = json['data'] != null && json['data'] is Map;
    final hasBooks = json['books'] != null && json['books'] is Map;
    final hasSubcategories =
        json['subcategories'] != null && json['subcategories'] is List;

    return hasData || hasBooks || hasSubcategories;
  }

  /// Load a specific category by name (lazy loading)
  Future<BookCategory?> loadCategory(String categoryName) async {
    try {
      final allData = await loadData();
      return allData[categoryName];
    } catch (e) {
      _logger.severe('Failed to load category $categoryName: $e');
      rethrow;
    }
  }

  /// Get list of available category names
  Future<List<String>> getAvailableCategories() async {
    try {
      final allData = await loadData();
      return allData.keys.toList();
    } catch (e) {
      _logger.severe('Failed to get available categories: $e');
      rethrow;
    }
  }

  /// Check if data is cached
  bool get isDataCached => _cachedData != null;

  /// Get cache size (number of categories)
  int get cacheSize => _cachedData?.length ?? 0;
}
