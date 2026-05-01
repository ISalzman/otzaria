import 'dart:ui' as ui;

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/theme/layout_tokens.dart';

double _currentLogicalScreenWidth() {
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) {
    return LayoutBreakpoints.expanded;
  }

  final view = views.first;
  if (view.devicePixelRatio == 0) {
    return LayoutBreakpoints.expanded;
  }

  return view.physicalSize.width / view.devicePixelRatio;
}

bool isCompactReadingLayout({double? screenWidth}) {
  final effectiveWidth = screenWidth ?? _currentLogicalScreenWidth();
  return effectiveWidth < LayoutBreakpoints.compact;
}

bool shouldAutoOpenReadingLeftPane({double? screenWidth}) {
  if (Settings.getValue<bool>('key-pin-sidebar') ?? false) {
    return true;
  }

  final isDefaultOpen =
      Settings.getValue<bool>('key-default-sidebar-open') ?? false;
  if (!isDefaultOpen) {
    return false;
  }

  return !isCompactReadingLayout(screenWidth: screenWidth);
}

bool resolveInitialReadingLeftPaneVisibility({
  required bool explicitOpen,
  required bool hasSearchText,
  double? screenWidth,
}) {
  if (Settings.getValue<bool>('key-pin-sidebar') ?? false) {
    return true;
  }

  if (explicitOpen) {
    return true;
  }

  if (isCompactReadingLayout(screenWidth: screenWidth)) {
    return false;
  }

  return hasSearchText;
}

bool resolveRestoredReadingLeftPaneState(
  Map<String, dynamic> json, {
  double? screenWidth,
}) {
  final savedShowLeftPane = json['showLeftPane'];
  if (savedShowLeftPane is bool) {
    return savedShowLeftPane;
  }

  return shouldAutoOpenReadingLeftPane(screenWidth: screenWidth);
}