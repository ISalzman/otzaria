import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';

import '../providers/shamor_zachor_data_provider.dart';
import '../providers/shamor_zachor_progress_provider.dart';
import '../widgets/book_card_widget.dart';
import '../models/book_model.dart';

/// Screen for browsing and searching books
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  static final Logger _logger = Logger('BooksScreen');

  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  List<BookSearchResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _logger.fine('Initialized BooksScreen');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Perform search across all books
  void _performSearch(String query) {
    if (query.length < 2) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    final dataProvider = context.read<ShamorZachorDataProvider>();
    final results = dataProvider.searchBooks(query);

    setState(() {
      _searchResults = results;
      _isSearching = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Consumer<ShamorZachorDataProvider>(
      builder: (context, dataProvider, child) {
        if (dataProvider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('טוען ספרים...'),
              ],
            ),
          );
        }

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
                  'שגיאה בטעינת ספרים',
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

        if (!dataProvider.hasData) {
          return const Center(
            child: Text('אין נתונים להצגה'),
          );
        }

        final categories = dataProvider.getCategoryNames()..sort();

        return DefaultTabController(
          length: categories.length,
          child: Column(
            children: [
              // Search field remains outside the scrolling/tab view
              _buildSearchField(),

              // The rest of the screen is either search results or tabs, and it needs to fill the remaining space
              Expanded(
                child: _isSearching
                    ? _buildSearchResults() // This widget already returns an Expanded
                    : Column(
                        children: [
                          TabBar(
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: categories
                                .map((name) => Tab(text: name))
                                .toList(),
                          ),
                          Expanded(
                            child: TabBarView(
                              children: categories.map((categoryName) {
                                return _buildCategoryView(
                                    dataProvider, categoryName);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build search field
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'חיפוש ספר או קטגוריה...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: _performSearch,
      ),
    );
  }

  /// Build search results
  Widget _buildSearchResults() {
    return Expanded(
      child: _searchResults.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'לא נמצאו תוצאות',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'נסה מילות חיפוש אחרות',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            )
          : _buildSearchResultsGrid(),
    );
  }

  /// Build search results grid
  Widget _buildSearchResultsGrid() {
    return Consumer<ShamorZachorProgressProvider>(
      builder: (context, progressProvider, child) {
        return GridView.builder(
          key: const PageStorageKey('search_results_grid'),
          padding: const EdgeInsets.all(16.0),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 3 / 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final result = _searchResults[index];
            final bookProgress = progressProvider.getProgressForBook(
              result.categoryName,
              result.bookDetails.toString(), // This is a temporary fix
            );

            return BookCardWidget(
              topLevelCategoryKey: result.categoryName,
              categoryName: result.categoryName,
              bookName: 'Search Result', // This needs proper implementation
              bookDetails: result.bookDetails,
              bookProgressData: bookProgress,
            );
          },
        );
      },
    );
  }

  /// Build view for a specific category
  Widget _buildCategoryView(
      ShamorZachorDataProvider dataProvider, String categoryName) {
    final category = dataProvider.getCategory(categoryName);
    if (category == null) {
      return const Center(child: Text('קטגוריה לא נמצאה'));
    }

    final items = <_BookItem>[];

    // Add direct books
    category.books.forEach((bookName, bookDetails) {
      items.add(_BookItem(
        topLevelCategoryKey: categoryName,
        categoryName: categoryName,
        bookName: bookName,
        bookDetails: bookDetails,
      ));
    });

    // Add books from subcategories
    if (category.subcategories != null) {
      for (final subCategory in category.subcategories!) {
        subCategory.books.forEach((bookName, bookDetails) {
          items.add(_BookItem(
            topLevelCategoryKey: categoryName,
            categoryName: subCategory.name,
            bookName: bookName,
            bookDetails: bookDetails,
          ));
        });
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'אין ספרים בקטגוריה זו',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
      );
    }

    return _buildBookGrid(items);
  }

  /// Build grid of books
  Widget _buildBookGrid(List<_BookItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // קובעים כמה עמודות להציג לפי רוחב המסך
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 500) {
          crossAxisCount = 3;
        }

        return Consumer<ShamorZachorProgressProvider>(
          builder: (context, progressProvider, child) {
            return GridView.builder(
              key: PageStorageKey(
                  'books_grid_${items.isNotEmpty ? items.first.topLevelCategoryKey : 'empty'}'),
              padding: const EdgeInsets.all(16.0),
              // משתמשים ב-Delegate היציב והנכון
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 175, // 🔧 <--- קובעים גובה קבוע לכל פריט
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bookProgress = progressProvider.getProgressForBook(
                  item.topLevelCategoryKey,
                  item.bookName,
                );

                return BookCardWidget(
                  topLevelCategoryKey: item.topLevelCategoryKey,
                  categoryName: item.categoryName,
                  bookName: item.bookName,
                  bookDetails: item.bookDetails,
                  bookProgressData: bookProgress,
                );
              },
            );
          },
        );
      },
    );
  }

  /// Focus the search field
  void focusSearchField() {
    // Focus the search field if it exists
    if (mounted) {
      // This will be handled by the search field's focus node if implemented
      _logger.info('Focusing search field');
    }
  }
}

/// Helper class for book items
class _BookItem {
  final String topLevelCategoryKey;
  final String categoryName;
  final String bookName;
  final BookDetails bookDetails;

  const _BookItem({
    required this.topLevelCategoryKey,
    required this.categoryName,
    required this.bookName,
    required this.bookDetails,
  });
}

/// Helper class for search book items
class _SearchBookItem extends _BookItem {
  const _SearchBookItem({
    required super.topLevelCategoryKey,
    required super.categoryName,
    required super.bookName,
    required super.bookDetails,
  });
}
