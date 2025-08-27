import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../models/book_model.dart';
import '../models/error_model.dart';
import '../services/data_loader_service.dart';

/// Provider for managing book data in Shamor Zachor
/// This provider is scoped locally within the ShamorZachorWidget
class ShamorZachorDataProvider with ChangeNotifier {
  static final Logger _logger = Logger('ShamorZachorDataProvider');
  
  final DataLoaderService _dataLoaderService;
  Map<String, BookCategory> _allBookData = {};
  bool _isLoading = false;
  ShamorZachorError? _error;

  /// Get all book data
  Map<String, BookCategory> get allBookData => _allBookData;
  
  /// Check if data is currently loading
  bool get isLoading => _isLoading;
  
  /// Get current error, if any
  ShamorZachorError? get error => _error;
  
  /// Check if data has been loaded
  bool get hasData => _allBookData.isNotEmpty;

  ShamorZachorDataProvider({DataLoaderService? dataLoaderService})
      : _dataLoaderService = dataLoaderService ?? DataLoaderService(
          assetsBasePath: 'packages/shamor_zachor/assets/data/'
        ) {
    _loadInitialData();
  }

  /// Load initial data on provider creation
  Future<void> _loadInitialData() async {
    await loadAllData();
  }

  /// Load all book categories and data
  Future<void> loadAllData() async {
    if (_isLoading) return; // Prevent concurrent loads
    
    _logger.info('Starting to load all data...');
    _dataLoaderService.clearCache();
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _logger.info('Calling dataLoaderService.loadData()...');
      _allBookData = await _dataLoaderService.loadData();
      _logger.info('Data loaded successfully. Categories: ${_allBookData.keys.toList()}');
      _logger.info('Successfully loaded ${_allBookData.length} categories');
      
      // Log category structure for debugging
      if (kDebugMode) {
        _allBookData.forEach((key, category) {
          _logger.fine('Category: ${category.name}');
          _logger.fine('  Has subcategories: ${category.subcategories?.isNotEmpty ?? false}');
          _logger.fine('  Direct books count: ${category.books.length}');
          
          if (category.subcategories != null && category.subcategories!.isNotEmpty) {
            for (var subCat in category.subcategories!) {
              _logger.fine('    SubCategory: ${subCat.name}, Books: ${subCat.books.length}');
              if (subCat.subcategories != null && subCat.subcategories!.isNotEmpty) {
                for (var deepSubCat in subCat.subcategories!) {
                  _logger.fine('      DeepSubCategory: ${deepSubCat.name}, Books: ${deepSubCat.books.length}');
                }
              }
            }
          }
        });
      }
    } catch (e, stackTrace) {
      if (e is ShamorZachorError) {
        _error = e;
      } else {
        _error = ShamorZachorError.fromException(
          e,
          stackTrace: stackTrace,
          customMessage: 'Failed to load book data',
        );
      }
      _logger.severe('Error loading data: ${_error!.message}', e, stackTrace);
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Get a specific category by name
  BookCategory? getCategory(String categoryName) {
    return _allBookData[categoryName];
  }

  /// Get book details for a specific book
  BookDetails? getBookDetails(String categoryName, String bookName) {
    final category = _allBookData[categoryName];
    if (category == null) return null;
    
    // First check direct books
    if (category.books.containsKey(bookName)) {
      return category.books[bookName];
    }
    
    // Then search in subcategories
    final searchResult = category.findBookRecursive(bookName);
    return searchResult?.bookDetails;
  }

  /// Search for books across all categories
  List<BookSearchResult> searchBooks(String query) {
    if (query.isEmpty) return [];
    
    final results = <BookSearchResult>[];
    final queryLower = query.toLowerCase();
    
    for (final category in _allBookData.values) {
      // Search in direct books
      for (final entry in category.books.entries) {
        if (entry.key.toLowerCase().contains(queryLower)) {
          results.add(BookSearchResult(entry.value, category.name, category));
        }
      }
      
      // Search in subcategories
      if (category.subcategories != null) {
        for (final subCategory in category.subcategories!) {
          _searchInCategory(subCategory, queryLower, results);
        }
      }
    }
    
    return results;
  }

  /// Helper method to search recursively in categories
  void _searchInCategory(BookCategory category, String queryLower, List<BookSearchResult> results) {
    // Search in direct books
    for (final entry in category.books.entries) {
      if (entry.key.toLowerCase().contains(queryLower)) {
        results.add(BookSearchResult(entry.value, category.name, category));
      }
    }
    
    // Search in subcategories
    if (category.subcategories != null) {
      for (final subCategory in category.subcategories!) {
        _searchInCategory(subCategory, queryLower, results);
      }
    }
  }

  /// Get all available category names
  List<String> getCategoryNames() {
    return _allBookData.keys.toList();
  }

  /// Get all books from a category (including subcategories)
  Map<String, BookDetails> getAllBooksFromCategory(String categoryName) {
    final category = _allBookData[categoryName];
    if (category == null) return {};
    
    return category.getAllBooksRecursive();
  }

  /// Retry loading data after an error
  Future<void> retry() async {
    if (_error != null && _error!.isRecoverable) {
      await loadAllData();
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get statistics about loaded data
  Map<String, int> getDataStatistics() {
    int totalCategories = _allBookData.length;
    int totalBooks = 0;
    int totalSubcategories = 0;
    
    for (final category in _allBookData.values) {
      totalBooks += category.books.length;
      if (category.subcategories != null) {
        totalSubcategories += category.subcategories!.length;
        for (final subCategory in category.subcategories!) {
          totalBooks += subCategory.getAllBooksRecursive().length;
        }
      }
    }
    
    return {
      'categories': totalCategories,
      'subcategories': totalSubcategories,
      'books': totalBooks,
    };
  }

  /// Check if a specific category exists
  bool hasCategory(String categoryName) {
    return _allBookData.containsKey(categoryName);
  }

  /// Check if a specific book exists in a category
  bool hasBook(String categoryName, String bookName) {
    return getBookDetails(categoryName, bookName) != null;
  }

  @override
  void dispose() {
    _logger.fine('Disposing ShamorZachorDataProvider');
    super.dispose();
  }
}