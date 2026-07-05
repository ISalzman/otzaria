import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart' as engine;

class SearchModeScopedParameters {
  final Map<String, String> customSpacing;
  final Map<int, List<String>> alternativeWords;
  final Map<String, Map<String, bool>> searchOptions;

  const SearchModeScopedParameters({
    this.customSpacing = const {},
    this.alternativeWords = const {},
    this.searchOptions = const {},
  });
}

/// מחלקת שירות לריכוז עיבוד קלט החיפוש בצד האפליקציה.
///
/// המחלקה מטפלת רק בפעולות UI כגון ניקוי טקסט, פיצול מילים לצורך
/// מפתחות הגדרות, ונרמול בחירות המשתמש. בניית שאילתות מנוע מתבצעת
/// בחבילת `search_engine`.
class SearchQueryBuilder {
  SearchQueryBuilder._();

  static const String typoToleranceOptionKey = 'שגיאות כתיב';
  static const List<String> availableWordOptionKeys = [
    'קידומות דקדוקיות',
    'סיומות דקדוקיות',
    'קידומות',
    'סיומות',
    'כתיב מלא/חסר',
    'חלק ממילה',
    typoToleranceOptionKey,
  ];

  static String buildWordKey(String word, int index) => '${word}_$index';

  static Map<String, bool> disabledWordOptionsTemplate() => {
        for (final option in availableWordOptionKeys) option: false,
      };

  /// פיצול שאילתה למילות חיפוש. מאציל למנוע ה-Rust
  /// ([`engine.splitQueryWords`]) שהוא מקור האמת היחיד, כך שהטוקניזציה
  /// בצד האפליקציה זהה תו-בתו לזו של האינדוקס והשאילתה במנוע:
  /// - `"` תמיד מפריד (`ז"ל` → שני טוקנים).
  /// - `'` בסוף מילה נשמר בטוקן (`תוס'`).
  /// - `'` באמצע מילה מפריד (`ד'אש` → `ד` + `אש`).
  static List<String> splitQueryWords(String query) =>
      engine.splitQueryWords(query: query);

  static bool usesAdvancedParameters(SearchMode searchMode) {
    return searchMode == SearchMode.advanced;
  }

  /// בונה מפת אפשרויות חיפוש אפקטיבית מתוך הגדרות גלובליות.
  /// יוצרת מפתח לכל מילה בשאילתה עם אותן אפשרויות.
  static Map<String, Map<String, bool>> expandGlobalOptionsToWords(
    String query,
    Map<String, bool> globalOptions,
  ) {
    if (globalOptions.isEmpty ||
        !globalOptions.values.any((enabled) => enabled)) {
      return const {};
    }
    final words = splitQueryWords(query);
    final result = <String, Map<String, bool>>{};
    for (var i = 0; i < words.length; i++) {
      result[buildWordKey(words[i], i)] = Map<String, bool>.from(globalOptions);
    }
    return result;
  }

  /// בוחר את מפת אפשרויות החיפוש האפקטיבית לפי המצב.
  /// במצב גלובלי - מרחיב את ההגדרות הגלובליות לכל מילה בשאילתה.
  /// במצב פר-מילה - מחזיר את ההגדרות הפר-מיליות כמות שהן.
  static Map<String, Map<String, bool>> effectiveSearchOptions({
    required String query,
    required bool useGlobalOptions,
    required Map<String, bool> globalOptions,
    required Map<String, Map<String, bool>> perWordOptions,
  }) {
    if (useGlobalOptions) {
      return expandGlobalOptionsToWords(query, globalOptions);
    }
    return perWordOptions;
  }

  static SearchModeScopedParameters normalizeParametersForMode(
    SearchMode searchMode, {
    Map<String, String>? customSpacing,
    Map<int, List<String>>? alternativeWords,
    Map<String, Map<String, bool>>? searchOptions,
  }) {
    if (!usesAdvancedParameters(searchMode)) {
      return const SearchModeScopedParameters();
    }

    final normalizedSpacing = <String, String>{};
    if (customSpacing != null) {
      for (final entry in customSpacing.entries) {
        final trimmedValue = entry.value.trim();
        if (trimmedValue.isNotEmpty) {
          normalizedSpacing[entry.key] = trimmedValue;
        }
      }
    }

    final normalizedAlternatives = <int, List<String>>{};
    if (alternativeWords != null) {
      for (final entry in alternativeWords.entries) {
        final cleanedWords = entry.value
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty)
            .toList(growable: false);
        if (cleanedWords.isNotEmpty) {
          normalizedAlternatives[entry.key] = cleanedWords;
        }
      }
    }

    final normalizedOptions = <String, Map<String, bool>>{};
    if (searchOptions != null) {
      for (final entry in searchOptions.entries) {
        final enabledOptions = <String, bool>{};
        for (final optionEntry in entry.value.entries) {
          if (optionEntry.value) {
            enabledOptions[optionEntry.key] = true;
          }
        }
        if (enabledOptions.isNotEmpty) {
          normalizedOptions[entry.key] = enabledOptions;
        }
      }
    }

    return SearchModeScopedParameters(
      customSpacing: normalizedSpacing,
      alternativeWords: normalizedAlternatives,
      searchOptions: normalizedOptions,
    );
  }

  /// ניקוי שאילתה מתווים מיוחדים שיכולים להפריע לחיפוש. מאציל למנוע ה-Rust
  /// ([`engine.sanitizeQuery`]) שהוא מקור האמת היחיד, כך שנרמול השאילתה
  /// ונרמול האינדוקס לא יכולים להיפרד:
  /// גרשיים וגרש עבריים (״ ׳) מומרים לגרשיים וגרש לועזיים (" ');
  /// המקף העברי (־) והמקף הלועזי (-) מומרים לרווח; רווחים מרובים מצומצמים.
  static String sanitizeQuery(String query) =>
      engine.sanitizeQuery(query: query);

  static Map<String, String> effectiveSpacingValues({
    required int wordCount,
    required Map<String, String> spacingValues,
    required int searchDistance,
  }) {
    if (spacingValues.isNotEmpty || searchDistance <= 0 || wordCount < 2) {
      return spacingValues;
    }

    return {
      for (var index = 0; index < wordCount - 1; index++)
        '$index-${index + 1}': '$searchDistance',
    };
  }
}
