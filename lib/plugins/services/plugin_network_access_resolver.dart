import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_network_allowlist.dart';

/// בודק האם URL מותר לגישת רשת של תוסף לפי שכבות האמון של אוצריא.
///
/// URL מאושר רק אם:
/// 1. הוא הוצהר ב-`network.allowlist` של התוסף עצמו.
/// 2. הוא מופיע בקובץ `plugin_network_allowlist.txt`: הגרסה החיה בשורש ענף
///    `dev` בריפו אוצריא ב-GitHub, או — כשאין רשת — העותק המקומפל שמחולל
///    מאותו קובץ בזמן הבנייה. עריכת הקובץ נכנסת לתוקף מיד אצל כל
///    המשתמשים, בלי release (ראו תיעוד ב-plugin_network_allowlist.dart).
///
/// אישורים שהגיעו מהקובץ הרשמי ב-GitHub נשמרים **בזיכרון בלבד** עד סגירת
/// האפליקציה; לא נכתבת שום קובץ cache לדיסק.
class PluginNetworkAccessResolver {
  PluginNetworkAccessResolver({
    this._client,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  static PluginNetworkAccessResolver instance = PluginNetworkAccessResolver();

  static const String _officialOwner = 'Otzaria';
  static const String _officialRepository = 'otzaria';
  static const String _officialBranch = 'dev';
  static const String _officialAllowlistFile = 'plugin_network_allowlist.txt';
  static const Duration _officialFetchTimeout = Duration(seconds: 15);
  static const Duration _officialFailureCacheTtl = Duration(minutes: 5);

  final http.Client? _client;
  final DateTime Function() _nowProvider;
  Future<List<String>?>? _pendingOfficialAllowlistFetch;
  List<String>? _officialAllowlistCache;
  DateTime? _officialAllowlistFailureUntil;

  /// URL ה-raw של קובץ ה-allowlist הרשמי בענף dev בריפו אוצריא.
  static Uri get officialAllowlistUri => Uri(
    scheme: 'https',
    host: 'raw.githubusercontent.com',
    pathSegments: <String>[
      _officialOwner,
      _officialRepository,
      _officialBranch,
      _officialAllowlistFile,
    ],
  );

  /// מאשר URL לתוסף אם הוא גם הוצהר במניפסט וגם אושר ע"י מקור אמון רשמי.
  Future<bool> isUriAllowedForPlugin(Uri uri, PluginManifest manifest) async {
    // שירותי AI מקומיים: כתובת loopback מותרת אם המניפסט הצהיר על ה-origin
    // המלא שלה, בלי לדרוש את ה-allowlist הגלובלי (שאינו נועד ל-localhost).
    // מסננים הצהרות host-בלבד (localhost / 127.0.0.1): הן היו מתירות כל פורט
    // מקומי — נתיב SSRF לשירותים אחרים על המחשב — ולכן נדרש origin מפורש.
    final loopbackDeclarations = manifest.networkAllowlist.where(
      (entry) => !isLoopbackHost(entry.trim()),
    );
    if (matchingLoopbackPrefix(uri, loopbackDeclarations) != null) {
      return true;
    }

    if (matchingNetworkAllowlistPrefix(uri, manifest.networkAllowlist) ==
        null) {
      return false;
    }

    final officialAllowlist = await _loadOfficialAllowlist();
    if (officialAllowlist != null) {
      // הקובץ בענף הייעודי הוא מקור האמת כשהוא זמין. חשוב לא לבדוק קודם את
      // העותק המקומפל: אחרת אי-אפשר לבטל במהירות כתובת שנפרצה או הוסרה.
      return matchingNetworkAllowlistPrefix(uri, officialAllowlist) != null;
    }

    // גיבוי לא-מקוון בלבד — אותו קובץ כפי שקומפל בזמן הבנייה. שומר על
    // תוספים קיימים כש-GitHub אינו זמין, אך אינו גובר על הרשימה החיה.
    return isUriAllowedForPluginNetwork(uri);
  }

  Future<List<String>?> _loadOfficialAllowlist() async {
    final cached = _officialAllowlistCache;
    if (cached != null) return cached;

    final failureUntil = _officialAllowlistFailureUntil;
    if (failureUntil != null && _nowProvider().isBefore(failureUntil)) {
      return null;
    }

    final pending = _pendingOfficialAllowlistFetch;
    if (pending != null) return pending;

    final fetch = _fetchOfficialAllowlist();
    _pendingOfficialAllowlistFetch = fetch;
    try {
      final result = await fetch;
      if (result != null) {
        _officialAllowlistCache = result;
        _officialAllowlistFailureUntil = null;
      } else {
        _officialAllowlistFailureUntil = _nowProvider().add(
          _officialFailureCacheTtl,
        );
      }
      return result;
    } finally {
      _pendingOfficialAllowlistFetch = null;
    }
  }

  Future<List<String>?> _fetchOfficialAllowlist() async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(officialAllowlistUri)
          .timeout(_officialFetchTimeout);
      if (response.statusCode != 200) {
        return null;
      }

      final allowlist = parsePluginNetworkAllowlistText(response.body);
      // גם רשימה ריקה היא תשובה רשמית תקפה (למשל השבתת-חירום של כל הגישה).
      // רק כשל HTTP/רשת מפעיל את הרשימה המקומפלת כגיבוי.
      return allowlist;
    } catch (_) {
      return null;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }
}
