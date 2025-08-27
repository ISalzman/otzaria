import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';

import '../providers/shamor_zachor_data_provider.dart';
import '../providers/shamor_zachor_progress_provider.dart';
import '../widgets/error_boundary.dart';
import 'tracking_screen.dart';
import 'books_screen.dart';

/// Main screen for Shamor Zachor with bottom navigation
class ShamorZachorMainScreen extends StatefulWidget {
  const ShamorZachorMainScreen({super.key});

  @override
  State<ShamorZachorMainScreen> createState() => _ShamorZachorMainScreenState();
}

class _ShamorZachorMainScreenState extends State<ShamorZachorMainScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  static final Logger _logger = Logger('ShamorZachorMainScreen');
  
  @override
  bool get wantKeepAlive => true;

  int _selectedIndex = 0;
  late final PageController _pageController;
  late final List<Widget> _screens;
  final GlobalKey<State<BooksScreen>> _booksScreenKey = GlobalKey<State<BooksScreen>>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _screens = [
      const TrackingScreen(),
      BooksScreen(key: _booksScreenKey),
    ];
    _logger.info('Initialized ShamorZachorMainScreen');
      }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex && mounted) {
      setState(() {
        _selectedIndex = index;
      });
      // Only animate if PageController is attached
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current screen title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.menu_book,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _getTitle(_selectedIndex),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Remove back button
        actions: _getActions(context, _selectedIndex),
        toolbarHeight: 105, // Increase height to accommodate both titles
      ),
      body: ErrorBoundary(
        child: Column(
          children: [
            Expanded(
              child: Consumer2<ShamorZachorDataProvider, ShamorZachorProgressProvider>(
                builder: (context, dataProvider, progressProvider, child) {
                  // Show loading state
                  if (dataProvider.isLoading || progressProvider.isLoading) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('טוען נתונים...'),
                        ],
                      ),
                    );
                  }

                  if (progressProvider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.storage_rounded,
                            size: 64,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'שגיאה בטעינת נתוני התקדמות',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            progressProvider.error!.userFriendlyMessage,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              // נסה לטעון מחדש את שני הספקים
                              dataProvider.loadAllData();
                              // צריך להוסיף מתודה לטעינה מחדש ב-progressProvider
                              // בינתיים, זו התחלה טובה
                            },
                            child: const Text('נסה שוב'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Show main content
                  return PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      if (mounted) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
                    },
                    children: _screens,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'מעקב',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'ספרים',
          ),
        ],
      ),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'מעקב לימוד';
      case 1:
        return 'ספרים';
      default:
        return 'שמור וזכור';
    }
  }

  List<Widget>? _getActions(BuildContext context, int index) {
    switch (index) {
      case 0: // Tracking screen
        return [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ShamorZachorProgressProvider>().clearError();
              context.read<ShamorZachorDataProvider>().loadAllData();
            },
            tooltip: 'רענן נתונים',
          ),
        ];
      case 1: // Books screen
        return [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Switch to books screen and focus search
              if (_selectedIndex != 1) {
                _onItemTapped(1);
              }
              // Focus search field after a short delay
              Future.delayed(const Duration(milliseconds: 100), () {
                final state = _booksScreenKey.currentState;
                if (state != null && state.mounted) {
                  // Call focusSearchField if the state has this method
                  try {
                    (state as dynamic).focusSearchField();
                  } catch (e) {
                    // Ignore if method doesn't exist
                  }
                }
              });
              _logger.info('Search button pressed');
            },
            tooltip: 'חיפוש',
          ),
        ];
      default:
        return null;
    }
  }
}