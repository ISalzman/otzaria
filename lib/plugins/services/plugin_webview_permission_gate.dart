import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/storage/plugin_system_database.dart';

/// שער בקשות ההרשאה של ה-WebView של תוסף.
///
/// ## מה היה לפני
///
/// לשני ה-WebView של תוסף — טאב ורקע — לא היה `onPermissionRequest`. זה אינו
/// "ברירת מחדל שמרנית שנשארה כמו שהיא" אלא **דחייה שקטה**: המימוש ב-Windows
/// עוטף כל `PermissionRequested` של WebView2 ב-deferral, ואם אין callback ב-Dart
/// הוא מריץ `defaultBehaviour` שקובע `COREWEBVIEW2_PERMISSION_STATE_DENY`. כלומר
/// כל בקשה — קריאת לוח, גופנים מקומיים, מיקום, מיקרופון — נדחתה בלי שאיש החליט
/// זאת ובלי שהמשתמש נשאל, ובלי שורה בלוג שמסבירה לתוסף למה הוא נכשל.
///
/// התסמין שהביא לכאן: כפתור "הדבק" בתוסף עורך מסמכים לא הדביק את מה שבלוח.
/// `navigator.clipboard.read()` נדחה, והתוסף נפל לחוצץ פנימי — כלומר הדביק מה
/// שהועתק בתוכו ולא את מה שהמשתמש בחר, ובחירת פריט מהיסטוריית Win+V לא הגיעה
/// אליו בכלל. נמדד ב-Chromium על `file://`: `isSecureContext` הוא `true`, ומה
/// שחוסם את הקריאה הוא **ההרשאה בלבד** — ברגע שהיא מוענקת `read()` ו-`readText()`
/// שניהם עוברים.
///
/// ## ההחלטה
///
/// אותו מודל שכל שאר יכולות התוסף עוברות בו: **הצהרה במניפסט + הענקה בפועל**.
/// זה בדיוק מה ש-`PluginBridgeHandler` דורש מכל קריאת RPC, וההרשאה מופיעה
/// למשתמש במסך ההתקנה ובמסך ההגדרות ככל הרשאה אחרת — כך שאין כאן יכולת חדשה
/// שנפתחת לכל תוסף, אלא יכולת שמי שצריך אותה מבקש והמשתמש מאשר.
///
/// מה שאינו ממופה ב-[requirements] נדחה. זו אינה עצלות אלא הגבול: יכולת דפדפן
/// שאין לה הרשאה במניפסט אין למשתמש דרך לאשר, ולכן היא אינה יכולה להיפתח. כל
/// יכולת שתתווסף כאן צריכה הרשאה, תווית עברית ובדיקה — ולא רשומה בלבד.
///
/// ההבדל מהמצב הקודם הוא לא רק בתוצאה: דחייה נרשמת עכשיו בלוג הריצה של התוסף,
/// עם שם ההרשאה שחסרה. תוסף שנכשל יכול לדעת למה.
///
/// ## תלות פתוחה: `SavesInProfile`
///
/// השער הזה אינו שלם בלי שינוי אחד ב-`flutter_inappwebview_windows`. ה-IDL של
/// WebView2 קובע על `ICoreWebView2PermissionRequestedEventArgs3`:
///
/// > The permission state set from the `PermissionRequested` event is saved in
/// > the profile by default; it persists across sessions and becomes the new
/// > default behavior for future `PermissionRequested` events. […] Set the
/// > `SavesInProfile` property to `FALSE` to not persist the state beyond the
/// > current request.
///
/// המימוש הנוכחי אינו נוגע ב-`SavesInProfile`, ולכן ברירת המחדל (`TRUE`) חלה.
/// לכל תוספי אוצריא יש **פרופיל WebView2 אחד** (WebViewEnvironmentHolder — אותו
/// `userDataFolder`) וכולם נטענים מ-`file://`, כלומר **origin אחד**. משמעות
/// שלושת הדברים יחד:
///
/// 1. **הדחייה השקטה של היום כבר נשמרה.** במחשב שבו תוסף כלשהו ניסה לקרוא את
///    הלוח, קיים DENY מתמיד ל-`file://` + CLIPBOARD_READ, ויש סיכוי שהאירוע לא
///    יוצג שוב — כלומר השער לא יישאל וההרשאה לא תיפתח.
/// 2. **הענקה תדלוף בין תוספים.** ALLOW שנשמר הוא של ה-origin, ולא של התוסף.
/// 3. **ביטול הרשאה לא ייכנס לתוקף.** המשתמש יכבה את המתג, והפרופיל ימשיך
///    לאשר.
///
/// שלושתם נפתרים ב-`put_SavesInProfile(FALSE)` על ה-event args (מותנה ב-query
/// ל-`ICoreWebView2PermissionRequestedEventArgs3`), שמחזיר את ההחלטה להיות של
/// המאכסן בכל בקשה ובקשה. זה שינוי native ב-fork ואינו נגיש מ-Dart. עד שהוא
/// ייכנס, השער נכון בכוונתו אך אינו אכיף בכל מצב — וה-IDL אומר במפורש
/// ש„browser heuristics” משפיעות על השאלה אם האירוע ממשיך להיות מוצג.
class PluginWebViewPermissionGate {
  const PluginWebViewPermissionGate._();

  /// יכולת הדפדפן → ההרשאה במניפסט שנדרשת בשבילה.
  ///
  /// המפתח הוא `PermissionResourceType.toValue()` ולא הערך עצמו: ב-
  /// `PermissionResourceType` יש `operator ==` א-סימטרי (`value == _value`),
  /// ומפתח מפה שאינו סימטרי ב-`==` הוא מפה שמאבדת רשומות.
  static const Map<String, String> requirements = {
    'CLIPBOARD_READ': pluginClipboardReadPermission,
  };

  /// התשובה לבקשה של [request], אחרי בדיקת המניפסט וההענקה שנשמרה.
  ///
  /// אינה זורקת: חריגה כאן משאירה את ה-deferral של WebView2 פתוח, כלומר דף
  /// שממתין לתשובה שלא תבוא.
  static Future<PermissionResponse> respond({
    required InstalledPlugin plugin,
    required PermissionRequest request,
    required PluginRegistryRepository registry,
  }) async {
    try {
      final decision = await _decide(
        resources: request.resources,
        plugin: plugin,
        registry: registry,
      );
      if (decision.granted) {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      }
      _logDenial(plugin, request, decision.missingPermission);
    } catch (e) {
      debugPrint(
        'PluginWebViewPermissionGate: החלטה נכשלה לתוסף '
        '${plugin.pluginId} — נדחה. $e',
      );
    }
    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.DENY,
    );
  }

  static Future<_Decision> _decide({
    required List<PermissionResourceType> resources,
    required InstalledPlugin plugin,
    required PluginRegistryRepository registry,
  }) async {
    // בקשה בלי משאבים אינה "הכול מותר" אלא בקשה שאין מה לאשר בה.
    if (resources.isEmpty) return const _Decision.denied(null);

    for (final resource in resources) {
      final permission = requiredPermissionFor(resource);
      if (permission == null) return _Decision.denied(resource.toValue());
      if (!declaresPermission(plugin, permission)) {
        return _Decision.denied(permission);
      }
      if (await registry.getPermission(plugin.pluginId, permission) != true) {
        return _Decision.denied(permission);
      }
    }
    return const _Decision.granted();
  }

  /// ההרשאה שנדרשת ל-[resource], או `null` כשהיכולת אינה נפתחת לתוספים.
  @visibleForTesting
  static String? requiredPermissionFor(PermissionResourceType resource) {
    return requirements[resource.toValue()];
  }

  /// האם המניפסט הצהיר על [permission].
  ///
  /// כולל את אליאס התאימות לאחור, כמו ב-`PluginBridgeHandler`: תוסף ותיק
  /// שהצהיר על ההרשאה שממנה זו פוצלה אינו נשבר בעדכון.
  @visibleForTesting
  static bool declaresPermission(InstalledPlugin plugin, String permission) {
    final declared = plugin.manifest.permissions;
    return pluginBaselinePermissions.contains(permission) ||
        declared.contains(permission) ||
        declared.contains(pluginLegacyPermissionAliases[permission]);
  }

  static void _logDenial(
    InstalledPlugin plugin,
    PermissionRequest request,
    String? missing,
  ) {
    final resources = request.resources.map((r) => r.toValue()).join(', ');
    final reason = missing == null
        ? 'היכולת אינה נפתחת לתוספים'
        : 'חסרה ההרשאה $missing';
    final message =
        'בקשת הרשאת WebView נדחתה [$resources] מ-${request.origin}: $reason';
    debugPrint('PluginWebViewPermissionGate [${plugin.pluginId}]: $message');
    // fire-and-forget, כמו כל כתיבה ללוג הריצה.
    unawaited(
      PluginSystemDatabase.instance.writeLog(plugin.pluginId, 'warn', message),
    );
  }
}

class _Decision {
  final bool granted;

  /// ההרשאה שחסרה, או `null` כשהיכולת עצמה אינה ממופה.
  final String? missingPermission;

  const _Decision.granted() : granted = true, missingPermission = null;

  const _Decision.denied(this.missingPermission) : granted = false;
}
