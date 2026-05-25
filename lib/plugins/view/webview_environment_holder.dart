import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:otzaria/core/app_paths.dart';

/// מחזיק את ה-WebViewEnvironment הסינגלטוני עם userDataFolder הניתן לכתיבה.
///
/// בהתקנה מערכתית (Program Files), WebView2 מנסה כברירת מחדל לכתוב לצד
/// קובץ ה-EXE — תיקייה read-only למשתמש רגיל — ונכשל עם
/// "Cannot create the InAppWebView instance!".
/// הגדרת נתיב מפורש תחת APPDATA פותרת זאת.
class WebViewEnvironmentHolder {
  static WebViewEnvironment? _environment;
  // Future of an init that is currently in flight. Used to coalesce
  // concurrent callers so they wait for the same WebView2 environment
  // creation instead of each starting their own. Without this, the
  // pre-warm path in main.dart and a user-triggered plugin tab open
  // can race past the `_environment != null` guard while creation is
  // still pending, and end up spawning two Edge process trees with
  // only the second written into [_environment] — the first becomes
  // unreachable garbage that keeps running until process exit.
  static Future<void>? _initializeFuture;
  static const MethodChannel _nativeShutdownChannel = MethodChannel(
    'com.pichillilorenzo/flutter_inappwebview_manager',
  );

  /// מחזיר את ה-WebViewEnvironment שנוצר באתחול, או null בפלטפורמות שאינן Windows.
  static WebViewEnvironment? get environment => _environment;

  /// מאתחל את סביבת WebView2 עם תיקיית נתונים הניתנת לכתיבה.
  /// חייב להיקרא לפני יצירת כל InAppWebView.
  ///
  /// בטוח לקריאה מקבילית: קוראים מקבילים יחלקו את אותו future ויראו את
  /// אותה התוצאה. במקרה של כשל, ה-future מנוקה כך שניסיון הבא יבצע
  /// retry במקום להחזיר את אותה שגיאה שמורה.
  static Future<void> initialize() {
    if (!Platform.isWindows) return Future<void>.value();
    if (_environment != null) return Future<void>.value();
    return _initializeFuture ??= _runInitialize();
  }

  static Future<void> _runInitialize() async {
    try {
      final dataRoot = await AppPaths.getDataRootPath();
      final webviewDataFolder = p.join(dataRoot, 'webview2');
      await Directory(webviewDataFolder).create(recursive: true);
      _environment = await WebViewEnvironment.create(
        settings:
            WebViewEnvironmentSettings(userDataFolder: webviewDataFolder),
      );
    } finally {
      // בהצלחה: _environment מוגדר, ה-guard בכניסה ל-initialize יחזיר
      // מיידית. בכישלון: _environment עדיין null וקריאה הבאה לא תיתפס
      // ע"י future ישן עם שגיאה ישנה — היא תתחיל ניסיון אתחול חדש.
      _initializeFuture = null;
    }
  }

  /// Disposes the current Windows WebView environment after the old widget
  /// tree has been torn down during an in-process app restart.
  static Future<void> disposeForAppRestart() async {
    if (!Platform.isWindows) return;

    final environment = _environment;
    _environment = null;
    if (environment == null) return;

    environment.onNewBrowserVersionAvailable = null;
    environment.onBrowserProcessExited = null;
    environment.onProcessInfosChanged = null;

    try {
      await environment.dispose();
    } catch (_) {}
  }

  /// Best-effort teardown for process exit on Windows.
  static Future<void> shutdownForAppExit() async {
    if (!Platform.isWindows) return;

    final environment = _environment;
    _environment = null;

    if (environment != null) {
      environment.onNewBrowserVersionAvailable = null;
      environment.onBrowserProcessExited = null;
      environment.onProcessInfosChanged = null;

      try {
        await environment.dispose();
      } catch (_) {}
    }

    await Future<void>.delayed(Duration.zero);

    try {
      if (kDebugMode) {
        debugPrint(
          'WebViewEnvironmentHolder: requesting native shutdown preparation',
        );
      }
      await _nativeShutdownChannel.invokeMethod('prepareForEngineShutdown');
    } catch (_) {}
  }
}
