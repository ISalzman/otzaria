import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../models/progress_model.dart';
import '../models/book_model.dart';
import '../models/error_model.dart';
import '../services/progress_service.dart';

/// Events emitted when significant progress milestones are reached
enum CompletionEventType {
  bookCompleted,
  reviewCycleCompleted,
}

class CompletionEvent {
  final CompletionEventType type;
  final String? bookName;
  final String? categoryName;
  final int? reviewCycleNumber;

  const CompletionEvent(
    this.type, {
    this.bookName,
    this.categoryName,
    this.reviewCycleNumber,
  });

  @override
  String toString() {
    return 'CompletionEvent(type: $type, book: $bookName, category: $categoryName, review: $reviewCycleNumber)';
  }
}

/// Provider for managing user progress in Shamor Zachor
/// This provider is scoped locally within the ShamorZachorWidget
class ShamorZachorProgressProvider with ChangeNotifier {
  static final Logger _logger = Logger('ShamorZachorProgressProvider');

  final ProgressService _progressService;
  FullProgressMap _fullProgress = {};
  CompletionDatesMap _completionDates = {};
  bool _isLoading = false;
  ShamorZachorError? _error;

  // Column names for progress tracking
  static const String learnColumn = 'learn';
  static const String review1Column = 'review1';
  static const String review2Column = 'review2';
  static const String review3Column = 'review3';
  static const List<String> allColumnNames = [
    learnColumn,
    review1Column,
    review2Column,
    review3Column,
  ];

  // Stream for completion events
  final _completionEventController =
      StreamController<CompletionEvent>.broadcast();
  Stream<CompletionEvent> get completionEvents =>
      _completionEventController.stream;

  /// Check if data is currently loading
  bool get isLoading => _isLoading;

  /// Get current error, if any
  ShamorZachorError? get error => _error;

  /// Check if progress data has been loaded
  bool get hasData => _fullProgress.isNotEmpty;

  ShamorZachorProgressProvider({ProgressService? progressService})
      : _progressService = progressService ?? ProgressService() {
    _loadInitialProgress();
  }

  /// Load initial progress data
  Future<void> _loadInitialProgress() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _fullProgress = await _progressService.loadFullProgressData();
      _completionDates = await _progressService.loadCompletionDates();
      _logger.info(
          'Successfully loaded progress for ${_fullProgress.length} categories');
    } catch (e, stackTrace) {
      if (e is ShamorZachorError) {
        _error = e;
      } else {
        _error = ShamorZachorError.fromException(
          e,
          stackTrace: stackTrace,
          customMessage: 'Failed to load progress data',
        );
      }
      _logger.severe(
          'Error loading progress: ${_error!.message}', e, stackTrace);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get progress data for a specific book
  Map<String, PageProgress> getProgressForBook(
      String categoryName, String bookName) {
    return _fullProgress[categoryName]?[bookName] ?? {};
  }

  /// Get progress for a specific item
  PageProgress getProgressForItem(
      String categoryName, String bookName, int absoluteIndex) {
    return _fullProgress[categoryName]?[bookName]?[absoluteIndex.toString()] ??
        PageProgress();
  }

  /// Update progress for a single item
  Future<void> updateProgress(
    String categoryName,
    String bookName,
    int absoluteIndex,
    String columnName,
    bool value,
    BookDetails bookDetails, {
    bool isBulkUpdate = false,
  }) async {
    try {
      final itemIndexKey = absoluteIndex.toString();

      // Save to storage (with debouncing)
      await _progressService.saveProgress(
        categoryName,
        bookName,
        itemIndexKey,
        columnName,
        value,
      );

      // Update local state
      _fullProgress.putIfAbsent(categoryName, () => {});
      _fullProgress[categoryName]!.putIfAbsent(bookName, () => {});
      _fullProgress[categoryName]![bookName]!
          .putIfAbsent(itemIndexKey, () => PageProgress());

      final pageProgress =
          _fullProgress[categoryName]![bookName]![itemIndexKey]!;
      pageProgress.setProperty(columnName, value);

      // Clean up empty entries
      if (pageProgress.isEmpty) {
        _fullProgress[categoryName]![bookName]!.remove(itemIndexKey);
        if (_fullProgress[categoryName]![bookName]!.isEmpty) {
          _fullProgress[categoryName]!.remove(bookName);
          if (_fullProgress[categoryName]!.isEmpty) {
            _fullProgress.remove(categoryName);
          }
        }
      }

      // Handle completion events (only for non-bulk updates)
      if (value && !isBulkUpdate) {
        await _handleCompletionEvents(
            categoryName, bookName, columnName, bookDetails);
      }

      notifyListeners();
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to update progress',
      );
      _logger.severe(
          'Error updating progress: ${_error!.message}', e, stackTrace);
      notifyListeners();
    }
  }

  /// Handle completion events when progress is updated
  Future<void> _handleCompletionEvents(
    String categoryName,
    String bookName,
    String columnName,
    BookDetails bookDetails,
  ) async {
    if (columnName == learnColumn) {
      final wasAlreadyCompleted =
          getCompletionDateSync(categoryName, bookName) != null;
      final isNowComplete =
          isBookCompleted(categoryName, bookName, bookDetails);

      if (isNowComplete && !wasAlreadyCompleted) {
        await _progressService.saveCompletionDate(categoryName, bookName);
        _completionDates = await _progressService.loadCompletionDates();

        _completionEventController.add(CompletionEvent(
          CompletionEventType.bookCompleted,
          bookName: bookName,
          categoryName: categoryName,
        ));
      }
    } else if (columnName.startsWith('review')) {
      int? reviewCycleNumber;
      switch (columnName) {
        case review1Column:
          reviewCycleNumber = 1;
          break;
        case review2Column:
          reviewCycleNumber = 2;
          break;
        case review3Column:
          reviewCycleNumber = 3;
          break;
      }

      if (reviewCycleNumber != null) {
        final cycleJustCompleted = _isReviewCycleCompleted(
          categoryName,
          bookName,
          reviewCycleNumber,
          bookDetails,
        );

        if (cycleJustCompleted) {
          _completionEventController.add(CompletionEvent(
            CompletionEventType.reviewCycleCompleted,
            bookName: bookName,
            categoryName: categoryName,
            reviewCycleNumber: reviewCycleNumber,
          ));
        }
      }
    }
  }

  /// Toggle selection for all items in a column (bulk operation)
  Future<void> toggleSelectAllForColumn(
    String categoryName,
    String bookName,
    BookDetails bookDetails,
    String columnName,
    bool select,
  ) async {
    if (!allColumnNames.contains(columnName)) {
      _logger.warning('Invalid column name: $columnName');
      return;
    }

    try {
      _logger.info(
          'Bulk ${select ? 'selecting' : 'deselecting'} $columnName for $bookName');

      // Update all items
      for (final item in bookDetails.learnableItems) {
        await updateProgress(
          categoryName,
          bookName,
          item.absoluteIndex,
          columnName,
          select,
          bookDetails,
          isBulkUpdate: true,
        );
      }

      // Handle completion for learn column
      if (select && columnName == learnColumn) {
        final wasAlreadyCompleted =
            getCompletionDateSync(categoryName, bookName) != null;
        final isNowComplete =
            isBookCompleted(categoryName, bookName, bookDetails);

        if (isNowComplete && !wasAlreadyCompleted) {
          await _progressService.saveCompletionDate(categoryName, bookName);
          _completionDates = await _progressService.loadCompletionDates();
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to bulk update column',
      );
      _logger.severe('Error in bulk update: ${_error!.message}', e, stackTrace);
      notifyListeners();
    }
  }

  /// Get completion date for a book (synchronous)
  String? getCompletionDateSync(String categoryName, String bookName) {
    return _completionDates[categoryName]?[bookName];
  }

  /// Check if a book is completed (all items learned)
  bool isBookCompleted(
      String categoryName, String bookName, BookDetails bookDetails) {
    final bookProgress = getProgressForBook(categoryName, bookName);
    final totalTargetItems = bookDetails.totalLearnableItems;
    if (totalTargetItems == 0) return false;

    final learnedItemsCount =
        ProgressService.getCompletedPagesCount(bookProgress);
    return learnedItemsCount >= totalTargetItems;
  }

  /// Check if a review cycle is completed
  bool _isReviewCycleCompleted(
    String categoryName,
    String bookName,
    int reviewCycleNumber,
    BookDetails bookDetails,
  ) {
    final bookProgress = getProgressForBook(categoryName, bookName);
    final totalItems = bookDetails.totalLearnableItems;
    if (totalItems == 0 || bookProgress.isEmpty) return false;

    final completedItemsInCycle = ProgressService.getReviewCompletedPagesCount(
      bookProgress,
      reviewCycleNumber,
    );

    return completedItemsInCycle >= totalItems;
  }

  /// Get column selection states (all/none/partial)
  Map<String, bool?> getColumnSelectionStates(
    String categoryName,
    String bookName,
    BookDetails? bookDetails,
  ) {
    final columnStates = <String, bool?>{
      learnColumn: null,
      review1Column: null,
      review2Column: null,
      review3Column: null,
    };

    if (bookDetails == null) return columnStates;

    final bookProgress = _fullProgress[categoryName]?[bookName];
    final totalItems = bookDetails.totalLearnableItems;

    if (totalItems == 0) {
      columnStates.updateAll((key, value) => false);
      return columnStates;
    }

    for (final currentColumnName in allColumnNames) {
      int itemsChecked = 0;
      if (bookProgress != null) {
        for (final item in bookDetails.learnableItems) {
          final itemProgress = bookProgress[item.absoluteIndex.toString()];
          if (itemProgress?.getProperty(currentColumnName) ?? false) {
            itemsChecked++;
          }
        }
      }

      if (itemsChecked == 0) {
        columnStates[currentColumnName] = false;
      } else if (itemsChecked == totalItems) {
        columnStates[currentColumnName] = true;
      } else {
        columnStates[currentColumnName] = null; // Partial selection
      }
    }

    return columnStates;
  }

  /// Get progress percentage for learning
  double getLearnProgressPercentage(
      String categoryName, String bookName, BookDetails bookDetails) {
    final bookProgress = getProgressForBook(categoryName, bookName);
    final totalTargetItems = bookDetails.totalLearnableItems;
    if (totalTargetItems == 0) return 0.0;

    final learnedPagesCount =
        ProgressService.getCompletedPagesCount(bookProgress);
    return learnedPagesCount / totalTargetItems;
  }

  /// Get progress percentage for a specific review
  double getReviewProgressPercentage(
    String categoryName,
    String bookName,
    BookDetails bookDetails,
    int reviewNumber,
  ) {
    final bookProgress = getProgressForBook(categoryName, bookName);
    final totalTargetItems = bookDetails.totalLearnableItems;
    if (totalTargetItems == 0) return 0.0;

    final reviewPagesCount = ProgressService.getReviewCompletedPagesCount(
      bookProgress,
      reviewNumber,
    );
    return reviewPagesCount / totalTargetItems;
  }

  /// Get number of completed cycles (learn + reviews)
  int getNumberOfCompletedCycles(
      String categoryName, String bookName, BookDetails bookDetails) {
    final bookProgress = getProgressForBook(categoryName, bookName);
    final totalTargetItems = bookDetails.totalLearnableItems;
    if (totalTargetItems == 0) return 0;

    int cycles = 0;

    if (ProgressService.getCompletedPagesCount(bookProgress) >=
        totalTargetItems) {
      cycles++;
    }
    for (int i = 1; i <= 3; i++) {
      if (ProgressService.getReviewCompletedPagesCount(bookProgress, i) >=
          totalTargetItems) {
        cycles++;
      }
    }

    return cycles;
  }

  /// Check if book is in active review (completed but not all reviews done)
  bool isBookInActiveReview(
      String categoryName, String bookName, BookDetails bookDetails) {
    if (!isBookCompleted(categoryName, bookName, bookDetails)) {
      return false;
    }

    final r1Prog =
        getReviewProgressPercentage(categoryName, bookName, bookDetails, 1);
    final r2Prog =
        getReviewProgressPercentage(categoryName, bookName, bookDetails, 2);
    final r3Prog =
        getReviewProgressPercentage(categoryName, bookName, bookDetails, 3);

    final r1Active = r1Prog > 0 && r1Prog < 1.0;
    final r2Active = r1Prog == 1.0 && r2Prog > 0 && r2Prog < 1.0;
    final r3Active =
        r1Prog == 1.0 && r2Prog == 1.0 && r3Prog > 0 && r3Prog < 1.0;

    return r1Active || r2Active || r3Active;
  }

  /// Check if book is considered in progress
  bool isBookConsideredInProgress(
      String categoryName, String bookName, BookDetails bookDetails) {
    final bookProgressData = getProgressForBook(categoryName, bookName);
    if (bookProgressData.isEmpty) {
      return false;
    }

    final learnProgress =
        getLearnProgressPercentage(categoryName, bookName, bookDetails);
    if (learnProgress > 0 && learnProgress < 1.0) return true;

    // Check review progress
    for (int i = 1; i <= 3; i++) {
      final reviewProgress =
          getReviewProgressPercentage(categoryName, bookName, bookDetails, i);
      if (reviewProgress > 0 && reviewProgress < 1.0) return true;
    }

    return false;
  }

  /// Get book progress summary
  Future<BookProgressSummary> getBookProgressSummary(
    String categoryName,
    String bookName,
    BookDetails bookDetails,
  ) async {
    try {
      return await _progressService.getBookProgressSummary(
        categoryName,
        bookName,
        bookDetails,
      );
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to get progress summary for $categoryName/$bookName: $e\n$stackTrace',
      );

      // Fallback to local calculation
      final bookProgress = getProgressForBook(categoryName, bookName);
      final totalItems = bookDetails.totalLearnableItems;
      final completedItems =
          ProgressService.getCompletedPagesCount(bookProgress);
      final inProgressItems =
          bookProgress.values.where((p) => !p.isEmpty && !p.isComplete).length;
      final completionDate = getCompletionDateSync(categoryName, bookName);

      return BookProgressSummary(
        categoryName: categoryName,
        bookName: bookName,
        totalItems: totalItems,
        completedItems: completedItems,
        inProgressItems: inProgressItems,
        completionDate: completionDate,
      );
    }
  }

  /// Get all tracked books with progress
  List<Map<String, dynamic>> getTrackedBooks(
      Map<String, BookCategory> allBookData) {
    final tracked = <Map<String, dynamic>>[];
    final processedBookKeys = <String>{};

    // Process progress data
    _fullProgress.forEach((topLevelCategoryKey, booksProgressMap) {
      final topLevelCategoryObject = allBookData[topLevelCategoryKey];
      if (topLevelCategoryObject == null) return;

      booksProgressMap.forEach((bookNameFromProgress, progressDataForBook) {
        final searchResult =
            topLevelCategoryObject.findBookRecursive(bookNameFromProgress);
        if (searchResult != null) {
          final uniqueKey =
              '$topLevelCategoryKey-${searchResult.categoryName}-$bookNameFromProgress';
          if (!processedBookKeys.contains(uniqueKey)) {
            tracked.add({
              'topLevelCategoryKey': topLevelCategoryKey,
              'displayCategoryName': searchResult.categoryName,
              'bookName': bookNameFromProgress,
              'bookDetails': searchResult.bookDetails,
              'progressData': progressDataForBook,
            });
            processedBookKeys.add(uniqueKey);
          }
        }
      });
    });

    // Process completion dates
    _completionDates.forEach((topLevelCategoryKey, booksCompletionMap) {
      final topLevelCategoryObject = allBookData[topLevelCategoryKey];
      if (topLevelCategoryObject == null) return;

      booksCompletionMap.forEach((bookNameFromCompletion, completionDate) {
        final searchResult =
            topLevelCategoryObject.findBookRecursive(bookNameFromCompletion);
        if (searchResult != null) {
          final uniqueKey =
              '$topLevelCategoryKey-${searchResult.categoryName}-$bookNameFromCompletion';

          if (!processedBookKeys.contains(uniqueKey)) {
            tracked.add({
              'topLevelCategoryKey': topLevelCategoryKey,
              'displayCategoryName': searchResult.categoryName,
              'bookName': bookNameFromCompletion,
              'bookDetails': searchResult.bookDetails,
              'progressData': getProgressForBook(
                  topLevelCategoryKey, bookNameFromCompletion),
              'completionDate': completionDate,
            });
            processedBookKeys.add(uniqueKey);
          } else {
            // Add completion date to existing entry
            final existingEntry = tracked.firstWhere((item) =>
                item['topLevelCategoryKey'] == topLevelCategoryKey &&
                item['displayCategoryName'] == searchResult.categoryName &&
                item['bookName'] == bookNameFromCompletion);
            existingEntry['completionDate'] = completionDate;
          }
        }
      });
    });

    return tracked;
  }

  /// Export progress data
  Future<String?> exportProgressData() async {
    try {
      return await _progressService.exportProgressData();
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to export progress data',
      );
      _logger.severe(
          'Error exporting progress: ${_error!.message}', e, stackTrace);
      notifyListeners();
      return null;
    }
  }

  /// Import progress data
  Future<bool> importProgressData(String jsonData) async {
    try {
      final success = await _progressService.importProgressData(jsonData);
      if (success) {
        await _loadInitialProgress();
      }
      return success;
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to import progress data',
      );
      _logger.severe(
          'Error importing progress: ${_error!.message}', e, stackTrace);
      notifyListeners();
      return false;
    }
  }

  /// Clear all progress data
  Future<void> clearAllProgress() async {
    try {
      await _progressService.clearAllProgress();
      _fullProgress.clear();
      _completionDates.clear();
      notifyListeners();
    } catch (e, stackTrace) {
      _error = ShamorZachorError.fromException(
        e,
        stackTrace: stackTrace,
        customMessage: 'Failed to clear progress data',
      );
      _logger.severe(
          'Error clearing progress: ${_error!.message}', e, stackTrace);
      notifyListeners();
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.fine('Disposing ShamorZachorProgressProvider');
    _completionEventController.close();
    _progressService.dispose();
    super.dispose();
  }
}
