import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:otzaria/core/http_client_registry.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// שליחת דיווח משתמש על תוסף לאתר אוצריא, שמאתר את מפתח התוסף ומעביר לו.
///
/// בשונה מ-PluginInstallReportService, כשל אינו נבלע: הוא נזרק חזרה לתוסף
/// כדי שיוכל להודיע למשתמש ולנסות שוב (אין תור המתנה offline).
class PluginReportService {
  PluginReportService({http.Client? client}) : _client = client ?? _shared;

  static final Uri endpoint = Uri.parse(
    'https://otzaria.org/api/plugin-reports',
  );

  /// סוגי הדיווח המוכרים לשרת; ערך לא מוכר מתורגם ל-'other'.
  static const Set<String> reportTypes = {'bug', 'crash', 'content', 'other'};

  /// אורך מרבי לשדה הפירוט; טקסט ארוך יותר נחתך לפני השליחה.
  static const int maxDetailsLength = 5000;

  final http.Client _client;

  static final http.Client _shared = _createClient();
  static final Random _random = Random.secure();

  static http.Client _createClient() {
    final client = http.Client();
    HttpClientRegistry.register(client.close);
    return client;
  }

  /// מזהה דיווח בפורמט UUID v4 — מאפשר לשרת לזהות שליחה כפולה בניסיון חוזר.
  static String generateReportId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static String normalizeReportType(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return reportTypes.contains(value) ? value : 'other';
  }

  /// שולח את הדיווח ומחזיר את גוף התשובה של השרת. זורק בכל כשל —
  /// HTTP שאינו 2xx, שגיאת רשת או timeout.
  Future<Map<String, dynamic>> sendReport({
    required String pluginUid,
    required String pluginName,
    required String pluginVersion,
    required String details,
    String? reportType,
    String? reporterEmail,
    String? reportId,
  }) async {
    final trimmedDetails = details.trim();
    if (trimmedDetails.isEmpty) {
      throw Exception('details required');
    }

    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}

    final email = reporterEmail?.trim() ?? '';
    final payload = <String, dynamic>{
      'reportId': reportId ?? generateReportId(),
      'pluginUid': pluginUid,
      'pluginName': pluginName,
      'pluginVersion': pluginVersion,
      'reportType': normalizeReportType(reportType),
      'details': trimmedDetails.length > maxDetailsLength
          ? trimmedDetails.substring(0, maxDetailsLength)
          : trimmedDetails,
      if (email.isNotEmpty) 'reporterEmail': email,
      'appVersion': ?appVersion,
      'platform': Platform.operatingSystem,
    };

    http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw Exception('failed to send report: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('report rejected: HTTP ${response.statusCode}');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const {'success': true};
  }
}
