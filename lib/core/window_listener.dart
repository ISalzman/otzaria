import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:otzaria/services/sources_books_service.dart';

/// Window listener that handles window events properly to prevent crashes
class AppWindowListener extends WindowListener {
  @override
  void onWindowClose() {
    if (kDebugMode) {
      print('Window close requested');
    }

    try {
      // Perform cleanup operations here if needed
      _performCleanup();

      // Close the window properly
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // Use Future.microtask to avoid blocking the current execution
        Future.microtask(() async {
          await windowManager.destroy();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during window close: $e');
      }
      // Force exit if cleanup fails - but only as last resort
      exit(0);
    }
  }

  @override
  void onWindowFocus() {
    if (kDebugMode) {
      print('Window focused');
    }
  }

  @override
  void onWindowBlur() {
    if (kDebugMode) {
      print('Window blurred');
    }
  }

  @override
  void onWindowMinimize() {
    if (kDebugMode) {
      print('Window minimized');
    }
  }

  @override
  void onWindowRestore() {
    if (kDebugMode) {
      print('Window restored');
    }
  }

  @override
  void onWindowResize() {
    if (kDebugMode) {
      print('Window resized');
    }
  }

  @override
  void onWindowMove() {
    if (kDebugMode) {
      print('Window moved');
    }
  }

  /// Perform cleanup operations before closing
  void _performCleanup() {
    try {
      if (kDebugMode) {
        print('Performing cleanup operations...');
      }

      // Clear SourcesBooks data from memory
      SourcesBooksService().clearData();

      if (kDebugMode) {
        print('Cleanup completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during cleanup: $e');
      }
    }
  }

  /// Clean up the listener when disposing
  void dispose() {
    // Perform cleanup operations
    _performCleanup();

    // Remove this listener from window manager
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      windowManager.removeListener(this);
    }
  }
}
