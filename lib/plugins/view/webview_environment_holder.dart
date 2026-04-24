import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  /// מחזיר את ה-WebViewEnvironment שנוצר באתחול, או null בפלטפורמות שאינן Windows.
  static WebViewEnvironment? get environment => _environment;

  /// מאתחל את סביבת WebView2 עם תיקיית נתונים הניתנת לכתיבה.
  /// חייב להיקרא לפני יצירת כל InAppWebView.
  static Future<void> initialize() async {
    if (!Platform.isWindows) return;
    if (_environment != null) return;

    final dataRoot = await AppPaths.getDataRootPath();
    final webviewDataFolder = p.join(dataRoot, 'webview2');

    await Directory(webviewDataFolder).create(recursive: true);

    _environment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: webviewDataFolder),
    );
  }
}
