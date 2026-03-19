import 'dart:async';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class WindowPersistence {
  static const _kLeft = 'window_bounds_left';
  static const _kTop = 'window_bounds_top';
  static const _kWidth = 'window_bounds_width';
  static const _kHeight = 'window_bounds_height';
  static const _kIsMaximized = 'window_is_maximized';

  static const double _minWidth = 400;
  static const double _minHeight = 300;
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  static Timer? _debounce;
  static bool _restored = false;
  static bool _isRestoring = false;

  static bool get isRestoring => _isRestoring;

  static Future<void> restoreIfAny() async {
    if (_restored) return;
    _restored = true;
    _isRestoring = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isMaximized = prefs.getBool(_kIsMaximized) ?? false;
      final left = prefs.getDouble(_kLeft);
      final top = prefs.getDouble(_kTop);
      final width = prefs.getDouble(_kWidth);
      final height = prefs.getDouble(_kHeight);

      // If we don't have a complete set of bounds, do nothing.
      if (left == null || top == null || width == null || height == null) {
        if (isMaximized) {
          await windowManager.maximize();
        }
        return;
      }

      final clampedWidth = width < _minWidth ? _minWidth : width;
      final clampedHeight = height < _minHeight ? _minHeight : height;

      // Set bounds before maximizing so Windows records this as the "restore size".
      // Without this, unmaximize would revert to the runner's default dimensions
      // instead of the user's last chosen windowed size.
      await windowManager.setBounds(
        Rect.fromLTWH(left, top, clampedWidth, clampedHeight),
      );

      if (isMaximized) {
        await windowManager.maximize();
      }
    } finally {
      _isRestoring = false;
    }
  }

  static void scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      // Fire-and-forget; any failure here shouldn't crash the app.
      unawaited(_saveNow());
    });
  }

  static Future<void> saveNow() async {
    _debounce?.cancel();
    _debounce = null;

    try {
      await _saveNow();
    } catch (_) {
      // Ignore persistence errors; should never crash the app.
    }
  }

  static Future<void> _saveNow() async {
    final prefs = await SharedPreferences.getInstance();

    final isFullscreen = await windowManager.isFullScreen();
    final isMaximized = await windowManager.isMaximized();
    await prefs.setBool(_kIsMaximized, isMaximized);

    // When fullscreen or maximized, don't overwrite the last "normal" bounds.
    // getBounds() while maximized returns the full-screen rect, not the
    // windowed size — saving that would cause a visible jump on the next launch
    // (setBounds to full-screen rect, then maximize).
    if (isFullscreen || isMaximized) return;

    final bounds = await windowManager.getBounds();
    await prefs.setDouble(_kLeft, bounds.left);
    await prefs.setDouble(_kTop, bounds.top);
    await prefs.setDouble(_kWidth, bounds.width);
    await prefs.setDouble(_kHeight, bounds.height);
  }
}
