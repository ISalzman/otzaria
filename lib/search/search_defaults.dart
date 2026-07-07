import 'dart:convert';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/search/search_query_builder.dart';

/// ברירות מחדל לחיפוש: אפשרויות החיפוש המתקדם (7 תיבות הסימון), המרווח
/// בין מילים של החיפוש הרגיל, ומצב החיפוש שבו נפתח הדיאלוג.
/// חיפוש חדש נפתח לפי ברירת המחדל השמורה; שינוי בחלונית נשמר לסשן
/// הנוכחי בלבד וחוזר לברירת המחדל בהפעלה הבאה של התוכנה.
class SearchDefaults {
  static const _settingsKey = 'key-search-default-options';
  static const _distanceKey = 'key-search-default-distance';

  // מטמון הסשן: מצב האפשרויות כפי שהמשתמש השאיר אותן בדיאלוג האחרון.
  static Map<String, bool>? _sessionOptions;

  // מטמון הסשן: מצב החיפוש והמרווח כפי שהמשתמש השאיר אותם בדיאלוג
  // האחרון. בהפעלה הבאה חוזרים לברירת המחדל (מדויק / המרווח השמור).
  static SearchMode? _sessionMode;
  static int? _sessionDistance;

  SearchDefaults._();

  /// כלל המפתחות שמותר לשמור כברירת מחדל: 7 האפשרויות + "ניקוד"/"טעמים".
  static const List<String> _allowedOptionKeys = [
    ...SearchQueryBuilder.availableWordOptionKeys,
    ...SearchQueryBuilder.vocalizedWordOptionKeys,
  ];

  /// ברירת המחדל השמורה (בין הפעלות). מפתחות לא-מוכרים מסוננים.
  static Map<String, bool> loadDefaults() {
    final raw = Settings.getValue<String>(_settingsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (_allowedOptionKeys.contains(entry.key.toString()))
            entry.key.toString(): entry.value == true,
      };
    } catch (_) {
      return {};
    }
  }

  /// שומר את [options] כברירת המחדל לחיפושים חדשים.
  static void saveDefaults(Map<String, bool> options) {
    Settings.setValue<String>(_settingsKey, jsonEncode(options));
    _sessionOptions = Map<String, bool>.from(options);
  }

  /// האפשרויות שאיתן ייפתח חיפוש חדש: מצב הסשן אם קיים, אחרת ברירת המחדל.
  static Map<String, bool> initialOptionsForNewSearch() {
    return Map<String, bool>.from(_sessionOptions ?? loadDefaults());
  }

  /// משמר את מצב האפשרויות להמשך הסשן (נקרא בסגירת דיאלוג החיפוש).
  static void rememberSessionOptions(Map<String, bool> options) {
    _sessionOptions = Map<String, bool>.from(options);
  }

  // ── מצב החיפוש ──────────────────────────────────────────────────────

  /// מצב החיפוש שבו נפתח חיפוש חדש: מצב הסשן אם קיים, אחרת חיפוש רגיל
  /// (מדויק) — ברירת המחדל של פתיחת החיפוש.
  static SearchMode initialModeForNewSearch() {
    return _sessionMode ?? SearchMode.exact;
  }

  /// משמר את מצב החיפוש להמשך הסשן.
  static void rememberSessionMode(SearchMode mode) {
    _sessionMode = mode;
  }

  // ── מרווח בין מילים (חיפוש רגיל/מתקדם) ─────────────────────────────

  /// ברירת המחדל השמורה (בין הפעלות) למרווח בין מילים.
  static int loadDistanceDefault() {
    final value = Settings.getValue<int>(_distanceKey) ?? 0;
    return value < 0 ? 0 : value;
  }

  /// שומר את [distance] כברירת המחדל למרווח בחיפושים חדשים.
  static void saveDistanceDefault(int distance) {
    Settings.setValue<int>(_distanceKey, distance);
    _sessionDistance = distance;
  }

  /// המרווח שאיתו ייפתח חיפוש חדש: מצב הסשן אם קיים, אחרת ברירת המחדל.
  /// (חיפוש מקורב אינו משתמש בזה — המרחק שם הוא מרחק עריכה, לא מרווח.)
  static int initialDistanceForNewSearch() {
    return _sessionDistance ?? loadDistanceDefault();
  }

  /// משמר את המרווח להמשך הסשן (נקרא בסגירת דיאלוג החיפוש).
  static void rememberSessionDistance(int distance) {
    _sessionDistance = distance;
  }
}
