import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';
import 'package:kosher_dart/kosher_dart.dart';

import '../providers/shamor_zachor_data_provider.dart';
import '../providers/shamor_zachor_progress_provider.dart';
import '../widgets/book_card_widget.dart';
import '../models/book_model.dart';
import '../models/progress_model.dart';

enum TrackingFilter { inProgress, completed }

/// Screen for tracking learning progress
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with AutomaticKeepAliveClientMixin {
  
  static final Logger _logger = Logger('TrackingScreen');
  
  @override
  bool get wantKeepAlive => true;

  TrackingFilter _selectedFilter = TrackingFilter.inProgress;

  @override
  void initState() {
    super.initState();
    _logger.fine('Initialized TrackingScreen');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Consumer2<ShamorZachorDataProvider, ShamorZachorProgressProvider>(
      builder: (context, dataProvider, progressProvider, child) {
        // Handle loading state
        if (dataProvider.isLoading || progressProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('טוען נתוני מעקב...'),
              ],
            ),
          );
        }

        // Handle error state
        if (dataProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'שגיאה בטעינת נתונים',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  dataProvider.error!.userFriendlyMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => dataProvider.retry(),
                  child: const Text('נסה שוב'),
                ),
              ],
            ),
          );
        }

        final allBookData = dataProvider.allBookData;
        final trackedItems = progressProvider.getTrackedBooks(allBookData);

        final (inProgressItems, completedItems) = _categorizeTrackedItems(
          trackedItems,
          progressProvider,
        );

        return Column(
          children: [
            _buildFilterSegments(),
            Expanded(
              child: _buildBooksList(
                _selectedFilter == TrackingFilter.inProgress
                    ? inProgressItems
                    : completedItems,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build the filter segments (In Progress / Completed)
  Widget _buildFilterSegments() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SegmentedButton<TrackingFilter>(
        segments: const [
          ButtonSegment<TrackingFilter>(
            value: TrackingFilter.inProgress,
            label: Text('בתהליך'),
            icon: Icon(Icons.hourglass_empty_outlined),
          ),
          ButtonSegment<TrackingFilter>(
            value: TrackingFilter.completed,
            label: Text('הושלם'),
            icon: Icon(Icons.check_circle_outline),
          ),
        ],
        selected: {_selectedFilter},
        onSelectionChanged: (Set<TrackingFilter> newSelection) {
          if (mounted) {
            setState(() {
              _selectedFilter = newSelection.first;
            });
          }
        },
        showSelectedIcon: false,
      ),
    );
  }

  /// Build the books list based on current filter
  Widget _buildBooksList(List<Map<String, dynamic>> itemsData) {
    if (itemsData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == TrackingFilter.inProgress
                  ? Icons.hourglass_empty
                  : Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == TrackingFilter.inProgress
                  ? 'אין ספרים בתהליך כעת'
                  : 'עדיין לא סיימת ספרים',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == TrackingFilter.inProgress
                  ? 'התחל ללמוד ספר כדי לראות אותו כאן'
                  : 'סיים ספר כדי לראות אותו כאן',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double desiredCardWidth = 350;
        const double minCardHeight = 120;
        
        int crossAxisCount = (constraints.maxWidth / desiredCardWidth).floor();
        if (crossAxisCount < 1) crossAxisCount = 1;
        
        // Use list view for narrow screens
        if (constraints.maxWidth < 500 || crossAxisCount == 1) {
          return ListView.builder(
            key: PageStorageKey('tracking_list_${_selectedFilter.name}'),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: itemsData.length,
            itemBuilder: (context, index) {
              return _buildBookCard(itemsData[index]);
            },
          );
        }

        // Use grid view for wider screens
        final childWidth = (constraints.maxWidth - (16 * (crossAxisCount + 1))) / crossAxisCount;
        final aspectRatio = childWidth / minCardHeight;

        return GridView.builder(
          key: PageStorageKey('tracking_grid_${_selectedFilter.name}'),
          padding: const EdgeInsets.all(16.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 175,
          ),
          itemCount: itemsData.length,
          itemBuilder: (context, index) {
            return _buildBookCard(itemsData[index]);
          },
        );
      },
    );
  }

  /// Build a single book card
  Widget _buildBookCard(Map<String, dynamic> itemData) {
    return BookCardWidget(
      topLevelCategoryKey: itemData['topLevelCategoryKey'],
      categoryName: itemData['displayCategoryName'],
      bookName: itemData['bookName'],
      bookDetails: itemData['bookDetails'],
      bookProgressData: itemData['bookProgressData'],
      isFromTrackingScreen: true,
      completionDateOverride: itemData['completionDateOverride'],
      isInCompletedListContext: _selectedFilter == TrackingFilter.completed,
    );
  }

  /// Categorize tracked items into in-progress and completed
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _categorizeTrackedItems(
    List<Map<String, dynamic>> trackedItems,
    ShamorZachorProgressProvider progressProvider,
  ) {
    final inProgressItems = <Map<String, dynamic>>[];
    final completedItems = <Map<String, dynamic>>[];
    final processedBooks = <String>{};

    for (final item in trackedItems) {
      final topLevelCategoryKey = item['topLevelCategoryKey'] as String;
      final bookName = item['bookName'] as String;
      final bookDetails = item['bookDetails'] as BookDetails;
      final bookProgressData = item['progressData'] as Map<String, PageProgress>;

      // Create unique key to avoid duplicates
      final uniqueKey = '$topLevelCategoryKey:$bookName';
      if (processedBooks.contains(uniqueKey)) {
        continue;
      }
      processedBooks.add(uniqueKey);

      final completionDate = progressProvider.getCompletionDateSync(
        topLevelCategoryKey,
        bookName,
      );

      final cardData = {
        'topLevelCategoryKey': topLevelCategoryKey,
        'displayCategoryName': item['displayCategoryName'],
        'bookName': bookName,
        'bookDetails': bookDetails,
        'bookProgressData': bookProgressData,
        'completionDateOverride': completionDate,
      };

      final isCompleted = progressProvider.isBookCompleted(
        topLevelCategoryKey,
        bookName,
        bookDetails,
      );

      final isInProgress = progressProvider.isBookConsideredInProgress(
        topLevelCategoryKey,
        bookName,
        bookDetails,
      );

      if (isCompleted) {
        completedItems.add(cardData);
      } else if (isInProgress) {
        inProgressItems.add(cardData);
      }
    }

    // Sort completed items by completion date (newest first)
    completedItems.sort((a, b) {
      final dateA = a['completionDateOverride'] as String?;
      final dateB = b['completionDateOverride'] as String?;
      
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      
      try {
        final parsedA = DateTime.parse(dateA);
        final parsedB = DateTime.parse(dateB);
        return parsedB.compareTo(parsedA); // Newest first
      } catch (e) {
        _logger.warning('Failed to parse completion dates: $dateA, $dateB');
        return dateB.compareTo(dateA); // Fallback to string comparison
      }
    });

    // Sort in-progress items by progress percentage (highest first)
    inProgressItems.sort((a, b) {
      final progressA = progressProvider.getLearnProgressPercentage(
        a['topLevelCategoryKey'],
        a['bookName'],
        a['bookDetails'],
      );
      final progressB = progressProvider.getLearnProgressPercentage(
        b['topLevelCategoryKey'],
        b['bookName'],
        b['bookDetails'],
      );
      return progressB.compareTo(progressA); // Highest progress first
    });

    return (inProgressItems, completedItems);
  }

  /// Format Hebrew date for display
  String _formatHebrewDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final hebrewDate = JewishDate.fromDateTime(date);
      return hebrewDate.toString(); // This will give Hebrew date format
    } catch (e) {
      _logger.warning('Failed to format Hebrew date: $isoDate');
      return isoDate; // Fallback to original date
    }
  }
}