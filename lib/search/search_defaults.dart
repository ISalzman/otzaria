import 'dart:convert';

import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/search/search_query_builder.dart';

/// ברירות מחדל לאפשרויות החיפוש המתקדם (7 תיבות הסימון).
/// חיפוש חדש נפתח לפי ברירת המחדל השמורה; שינוי בחלונית נשמר לסשן
/// הנוכחי בלבד וחוזר לברירת המחדל בהפעלה הבאה של התוכנה.
class SearchDefaults {
  static const _settingsKey = 'key-search-default-options';

  // מטמון הסשן: מצב האפשרויות כפי שהמשתמש השאיר אותן בדיאלוג האחרון.
  static Map<String, bool>? _sessionOptions;

  SearchDefaults._();

  /// ברירת המחדל השמורה (בין הפעלות). מפתחות לא-מוכרים מסוננים.
  static Map<String, bool> loadDefaults() {
    final raw = Settings.getValue<String>(_settingsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (SearchQueryBuilder.availableWordOptionKeys
              .contains(entry.key.toString()))
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
}
