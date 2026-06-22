import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_network_allowlist.dart';

/// בודק האם URL מותר לגישת רשת של תוסף לפי שכבות האמון של אוצריא.
///
/// URL מאושר רק אם:
/// 1. הוא הוצהר ב-`network.allowlist` של התוסף עצמו.
/// 2. הוא מופיע גם ברשימה המובנית של אוצריא, או בקובץ ה-allowlist הרשמי
///    של אוצריא ב-GitHub.
///
/// אישורים שהגיעו מהקובץ הרשמי ב-GitHub נשמרים **בזיכרון בלבד** עד סגירת
/// האפליקציה; לא נכתבת שום קובץ cache לדיסק.
class PluginNetworkAccessResolver {
  PluginNetworkAccessResolver({
    http.Client? client,
    Future<String?> Function()? officialTagNameProvider,
    DateTime Function()? nowProvider,
  })  : _client = client,
        _officialTagNameProvider =
            officialTagNameProvider ?? _defaultOfficialTagNameProvider,
        _nowProvider = nowProvider ?? DateTime.now;

  static PluginNetworkAccessResolver instance = PluginNetworkAccessResolver();

  static const String _officialOwner = 'Otzaria';
  static const String _officialRepository = 'otzaria';
  static const String _officialAllowlistPath =
      'lib/plugins/models/plugin_network_allowlist.dart';
  static const Duration _officialFetchTimeout = Duration(seconds: 15);
  static const Duration _officialFailureCacheTtl = Duration(minutes: 5);

  final http.Client? _client;
  final Future<String?> Function() _officialTagNameProvider;
  final DateTime Function() _nowProvider;
  Future<List<String>?>? _pendingOfficialAllowlistFetch;
  List<String>? _officialAllowlistCache;
  DateTime? _officialAllowlistFailureUntil;
  final Set<String> _sessionApprovedOfficialPrefixes = <String>{};

  /// URL ה-raw הרשמי של קובץ ה-allowlist בריפו של אוצריא, מוצמד ל-tag.
  static Uri officialAllowlistUriForTag(String tagName) => Uri(
        scheme: 'https',
        host: 'raw.githubusercontent.com',
        pathSegments: <String>[
          _officialOwner,
          _officialRepository,
          'refs',
          'tags',
          tagName,
          ..._officialAllowlistPath.split('/'),
        ],
      );

  static Future<String?> _defaultOfficialTagNameProvider() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version.trim();
    if (version.isEmpty) return null;
    return version;
  }

  /// מאשר URL לתוסף אם הוא גם הוצהר במניפסט וגם אושר ע"י מקור אמון רשמי.
  Future<bool> isUriAllowedForPlugin(Uri uri, PluginManifest manifest) async {
    // שירותי AI מקומיים: כתובת loopback מותרת אם היא תואמת הצהרת loopback
    // במניפסט (לפי prefix — פורט/נתיב מפורשים נשמרים), בלי לדרוש את
    // ה-allowlist הגלובלי (שאינו נועד ל-localhost).
    if (matchingLoopbackPrefix(uri, manifest.networkAllowlist) != null) {
      return true;
    }

    if (matchingNetworkAllowlistPrefix(uri, manifest.networkAllowlist) ==
        null) {
      return false;
    }

    if (isUriAllowedForPluginNetwork(uri)) {
      return true;
    }

    if (matchingNetworkAllowlistPrefix(uri, _sessionApprovedOfficialPrefixes) !=
        null) {
      return true;
    }

    final officialAllowlist = await _loadOfficialAllowlist();
    if (officialAllowlist == null) return false;

    final matchedOfficialPrefix =
        matchingNetworkAllowlistPrefix(uri, officialAllowlist);
    if (matchedOfficialPrefix == null) return false;

    _sessionApprovedOfficialPrefixes.add(matchedOfficialPrefix);
    return true;
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
        _officialAllowlistFailureUntil =
            _nowProvider().add(_officialFailureCacheTtl);
      }
      return result;
    } finally {
      _pendingOfficialAllowlistFetch = null;
    }
  }

  Future<List<String>?> _fetchOfficialAllowlist() async {
    final client = _client ?? http.Client();
    try {
      final officialTag = await _officialTagNameProvider();
      if (officialTag == null || officialTag.trim().isEmpty) {
        return null;
      }

      final candidateTags = <String>[
        officialTag,
        if (!officialTag.startsWith('v')) 'v$officialTag',
      ];

      for (final tag in candidateTags) {
        final response = await client
            .get(officialAllowlistUriForTag(tag))
            .timeout(_officialFetchTimeout);
        if (response.statusCode == 404) {
          continue;
        }
        if (response.statusCode != 200) {
          return null;
        }

        final allowlist =
            extractPluginNetworkAllowlistFromDartSource(response.body);
        return allowlist.isEmpty ? null : allowlist;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }
}
