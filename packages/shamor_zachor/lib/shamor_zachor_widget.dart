import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logging/logging.dart';

import 'shamor_zachor_config.dart';
import 'providers/shamor_zachor_data_provider.dart';
import 'providers/shamor_zachor_progress_provider.dart';
import 'screens/shamor_zachor_main_screen.dart';
import 'screens/book_detail_screen.dart';

/// Main widget for Shamor Zachor functionality
/// This is the only public API exposed by the package
class ShamorZachorWidget extends StatefulWidget {
  /// Optional configuration for customizing behavior
  final ShamorZachorConfig config;

  const ShamorZachorWidget({
    super.key,
    this.config = ShamorZachorConfig.defaultConfig,
  });

  @override
  State<ShamorZachorWidget> createState() => _ShamorZachorWidgetState();
}

class _ShamorZachorWidgetState extends State<ShamorZachorWidget>
    with AutomaticKeepAliveClientMixin {
  
  static final Logger _logger = Logger('ShamorZachorWidget');
  
  @override
  bool get wantKeepAlive => true;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _logger.info('Initializing ShamorZachorWidget');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Inherit theme from host app or use provided config
    final theme = widget.config.themeData ?? Theme.of(context);
    final textDirection = widget.config.textDirection ?? 
        Directionality.of(context);
    
    return Theme(
      data: theme,
      child: Directionality(
        textDirection: textDirection,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => ShamorZachorDataProvider(),
            ),
            ChangeNotifierProvider(
              create: (_) => ShamorZachorProgressProvider(),
            ),
          ],
          child: Navigator(
            key: _navigatorKey,
            initialRoute: '/',
            onGenerateRoute: _generateRoute,
            onPopPage: _onPopPage,
          ),
        ),
      ),
    );
  }

  /// Handle route generation for internal navigation
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    _logger.fine('Generating route for: ${settings.name}');
    
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (context) => const ShamorZachorMainScreen(),
          settings: settings,
        );
      
      case '/book_detail':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => BookDetailScreen(
            topLevelCategoryKey: args['topLevelCategoryKey'] as String,
            categoryName: args['categoryName'] as String,
            bookName: args['bookName'] as String,
          ),
          settings: settings,
        );
      
      default:
        _logger.warning('Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('דף לא נמצא'),
            ),
          ),
          settings: settings,
        );
    }
  }

  /// Handle page removal behavior
  bool _onPopPage(Route<dynamic> route, dynamic result) {
    if (!route.didPop(result)) {
      return false;
    }
    
    // If we're at the root route, don't pop - let the host app handle it
    if (route.settings.name == '/') {
      return false;
    }
    
    return true;
  }

  @override
  void dispose() {
    _logger.fine('Disposing ShamorZachorWidget');
    super.dispose();
  }
}