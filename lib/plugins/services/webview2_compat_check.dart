import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// בודק האם השילוב של Windows + WebView2 במכשיר ידוע כקורס כשטוענים
/// תוספים, ואם כן מסרב ליצור WebView.
///
/// השילוב הספציפי שאומת כקורס: Windows 10 build < 19041 (1903/1909)
/// + WebView2 Runtime v143 ומטה. הקריסה native ב-`MSVCP140!std::string`
/// בקריאה מ-`EmbeddedBrowserWebView.dll v143`, ולא ניתן לתפוס אותה ב-Dart.
///
/// **אסטרטגיה מכוונת ולא רחבה:** חוסמים רק את השילוב המאומת ולא בטוח
/// משביתים תוספים במכונות אחרות. כש-`getAvailableVersion()` מחזיר null
/// (לא מותקן WebView2) — חוסמים, כי WebView לא ייווצר בלאו הכי.
class WebView2CompatCheck {
  /// הגרסה הראשית המינימלית של Edge WebView2 הנדרשת *רק* כש-Windows
  /// הוא מתחת ל-Win10 2004. במערכות חדשות יותר אנו תומכים בכל גרסה.
  static const int minimumWebView2MajorOnOldWindows = 144;

  /// Build המינימלי של Windows שנחשב "חדש" לצורך הבדיקה.
  /// 19041 = Windows 10 2004 (May 2020). מתחת לזה — Win10 1909/1903 וישן יותר.
  static const int oldWindowsBuildThreshold = 19041;

  /// תוצאה מטמונה כדי לא לקרוא ל-IPC בכל build של widget.
  static WebView2CompatResult? _cached;

  /// בודק (פעם אחת) את גרסת WebView2 הזמינה במערכת.
  ///
  /// בפלטפורמות שאינן Windows, מחזיר תמיד supported (יש implementation אחר
  /// — Android WebView ו-WKWebView). הבדיקה רלוונטית ל-Windows בלבד.
  static Future<WebView2CompatResult> check() async {
    final cached = _cached;
    if (cached != null) return cached;
    final result = await _doCheck();
    _cached = result;
    return result;
  }

  static Future<WebView2CompatResult> _doCheck() async {
    if (kIsWeb || !Platform.isWindows) {
      return const WebView2CompatResult(
        supported: true,
        version: null,
        majorVersion: null,
        windowsBuild: null,
        reason: WebView2CompatReason.platformNotWindows,
      );
    }
    final windowsBuild = parseWindowsBuild(Platform.operatingSystemVersion);
    try {
      final version = await WebViewEnvironment.getAvailableVersion();
      return evaluate(
        version: version,
        windowsBuild: windowsBuild,
      );
    } catch (e) {
      debugPrint('WebView2CompatCheck failed: $e');
      // הבדיקה עצמה נכשלה. ב-Windows ישן זה סימן שאין WebView2 תקין —
      // לא ניצור WebView. ב-Windows חדש נסמוך על המנגנון המלא של flutter_inappwebview.
      return WebView2CompatResult(
        supported:
            windowsBuild != null && windowsBuild >= oldWindowsBuildThreshold,
        version: null,
        majorVersion: null,
        windowsBuild: windowsBuild,
        error: e.toString(),
        reason: WebView2CompatReason.probeFailed,
      );
    }
  }

  /// לוגיקת ההחלטה — מופרדת ל-method טהור כדי להקל על טסטים.
  @visibleForTesting
  static WebView2CompatResult evaluate({
    required String? version,
    required int? windowsBuild,
  }) {
    final major = parseMajor(version);

    // אין WebView2 מותקן בכלל — לא יכולים ליצור WebView. חוסמים בכל מקרה.
    if (version == null || version.isEmpty) {
      return WebView2CompatResult(
        supported: false,
        version: null,
        majorVersion: null,
        windowsBuild: windowsBuild,
        reason: WebView2CompatReason.webView2NotInstalled,
      );
    }

    // Windows חדש (>= Win10 2004 / Win 11): סומכים על WebView2 לכל גרסה.
    if (windowsBuild == null || windowsBuild >= oldWindowsBuildThreshold) {
      return WebView2CompatResult(
        supported: true,
        version: version,
        majorVersion: major,
        windowsBuild: windowsBuild,
        reason: WebView2CompatReason.modernWindows,
      );
    }

    // Windows ישן: חוסמים רק אם גם WebView2 ישן (הצירוף הקורס).
    if (major != null && major >= minimumWebView2MajorOnOldWindows) {
      return WebView2CompatResult(
        supported: true,
        version: version,
        majorVersion: major,
        windowsBuild: windowsBuild,
        reason: WebView2CompatReason.oldWindowsButRecentWebView2,
      );
    }

    return WebView2CompatResult(
      supported: false,
      version: version,
      majorVersion: major,
      windowsBuild: windowsBuild,
      reason: WebView2CompatReason.oldWindowsAndOldWebView2,
    );
  }

  /// מחלץ את מספר ה-build מתוך `Platform.operatingSystemVersion`.
  /// בפורמט "Windows 10 10.0 (Build 19045)" או "10.0.19041" וכו'.
  @visibleForTesting
  static int? parseWindowsBuild(String osVersion) {
    // נסיון 1: "(Build NNNN)" או "(Build NNNN.something)"
    final buildMatch =
        RegExp(r'Build\s+(\d+)', caseSensitive: false).firstMatch(osVersion);
    if (buildMatch != null) {
      final n = int.tryParse(buildMatch.group(1)!);
      if (n != null) return n;
    }
    // נסיון 2: "10.0.NNNNN" — האחרון מתוך שלושה חלקים מנוקדים.
    final dotted = RegExp(r'\b(\d+)\.(\d+)\.(\d+)\b').firstMatch(osVersion);
    if (dotted != null) {
      final n = int.tryParse(dotted.group(3)!);
      if (n != null) return n;
    }
    return null;
  }

  @visibleForTesting
  static int? parseMajor(String? version) {
    if (version == null || version.isEmpty) return null;
    final dot = version.indexOf('.');
    final firstPart = dot >= 0 ? version.substring(0, dot) : version;
    return int.tryParse(firstPart);
  }

  /// משמש לאיפוס המטמון בטסטים בלבד.
  @visibleForTesting
  static void resetCacheForTesting() {
    _cached = null;
  }
}

/// מציין למה התקבלה החלטת התאימות הספציפית (לטסטים ולוגים).
enum WebView2CompatReason {
  platformNotWindows,
  modernWindows,
  oldWindowsButRecentWebView2,
  oldWindowsAndOldWebView2,
  webView2NotInstalled,
  probeFailed,
}

/// תוצאת בדיקת תאימות WebView2.
class WebView2CompatResult {
  final bool supported;
  final String? version;
  final int? majorVersion;
  final int? windowsBuild;
  final String? error;
  final WebView2CompatReason reason;

  const WebView2CompatResult({
    required this.supported,
    required this.version,
    required this.majorVersion,
    required this.windowsBuild,
    required this.reason,
    this.error,
  });

  /// תיאור הסיבה לכך שאין תמיכה (לשימוש בהודעה למשתמש).
  String get reasonForUser {
    switch (reason) {
      case WebView2CompatReason.webView2NotInstalled:
        return 'לא נמצאה התקנה של Microsoft Edge WebView2 Runtime במכשיר.';
      case WebView2CompatReason.oldWindowsAndOldWebView2:
        return 'גרסת Windows במכשיר ישנה (build $windowsBuild) ולא תואמת '
            'את גרסת Edge WebView2 Runtime המותקנת (v$version). '
            'בקש לעדכן את WebView2 לגרסה '
            '${WebView2CompatCheck.minimumWebView2MajorOnOldWindows} ומעלה.';
      case WebView2CompatReason.probeFailed:
        return 'בדיקת תאימות Edge WebView2 Runtime נכשלה'
            '${error != null ? ': $error' : ''}.';
      case WebView2CompatReason.platformNotWindows:
      case WebView2CompatReason.modernWindows:
      case WebView2CompatReason.oldWindowsButRecentWebView2:
        return ''; // לא אמור להופיע ב-supported=false
    }
  }
}
