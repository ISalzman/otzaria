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

/// טווח של מילת-מנוע אחת ([SearchQueryBuilder.splitQueryWords]) בתוך
/// טקסט השאילתה הגולמי, לצורכי UI (איתור המילה שתחת הסמן, ניווט).
class QueryWordSpan {
  /// מילת המנוע המנורמלת (כפי שמופיעה במפתחות `"{word}_{index}"`).
  final String word;

  /// האינדקס בפיצול המלא של השאילתה.
  final int index;

  /// גבולות בטקסט הגולמי. כשלא ניתן לאתר את המילה בתוך המקטע
  /// (נורמליזציה משנת-אורך) — גבולות מקטע-הרווח כולו.
  final int start;
  final int end;

  const QueryWordSpan(this.word, this.index, this.start, this.end);
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
  /// - `"` בין אותיות הוא חלק מהמילה (`רמב"ם`, `ז"ל` — מילה אחת);
  ///   בקצה מילה — מפריד.
  /// - `'` בין אותיות או בסוף מילה נשמר בטוקן (`ג'ורג'`, `תוס'`).
  /// - `''` בין אותיות מאוחד ל-`"` (מוסכמת `רמב''ם` בקבצים ישנים);
  ///   ״/׳ עבריים מנורמלים ל-"/' לפני הפיצול.
  static List<String> splitQueryWords(String query) =>
      engine.splitQueryWords(query: query);

  /// קיפול שומר-אורך של צורות הגרש העבריות לצורת ה-ASCII שמילות
  /// [splitQueryWords] נושאות, כדי שאיתור מילה בטקסט הגולמי לא יזיז
  /// offsets. נורמליזציות משנות-אורך (`''`→`"`) אינן מטופלות כאן —
  /// [queryWordSpans] נופל לגבולות המקטע כולו במקרים אלה.
  static String foldQuoteForms(String text) =>
      text.replaceAll('״', '"').replaceAll('׳', "'");

  /// מיפוי מילות [splitQueryWords] לטווחיהן בטקסט הגולמי, מקטע-רווח
  /// אחרי מקטע-רווח. מקטע שמתפצל לכמה מילות מנוע (`בית-דין`) מקבל
  /// טווח נפרד לכל מילה, כך שהסמן על `דין` בוחר את `דין` ולא את
  /// `בית`. מילה שלא ניתן לאתר בתוך המקטע — נורמליזציה משנת-אורך
  /// (`רמב''ם`→`רמב"ם`) או פיסוק שקוף בתוך מילה (`א.ב`→`אב`) —
  /// מקבלת את הפער שבין שכנותיה המאותרות (או את גבולות המקטע כשאין),
  /// כך שגם במקטע מעורב כמו `רמב''ם-משה` הסמן על `משה` בוחר את `משה`:
  /// עדיף טווח גס ממיקום שגוי.
  static List<QueryWordSpan> queryWordSpans(String text) {
    final spans = <QueryWordSpan>[];
    var index = 0;
    for (final match in RegExp(r'\S+').allMatches(text)) {
      final chunk = match.group(0)!;
      final words = splitQueryWords(chunk);
      final folded = foldQuoteForms(chunk);

      // שלב 1: איתור לפי הסדר. כישלון (מילה ששונתה ע"י הנורמליזציה)
      // אינו עוצר את איתור המילים שאחריו — הן נבדקות מאותו מיקום.
      final locatedStarts = List<int?>.filled(words.length, null);
      var searchPos = 0;
      for (var i = 0; i < words.length; i++) {
        final rel = folded.indexOf(words[i], searchPos);
        if (rel != -1) {
          locatedStarts[i] = rel;
          searchPos = rel + words[i].length;
        }
      }

      // שלב 2: טווחים. מילה מאותרת — טווח מדויק; לא-מאותרת — הפער
      // מסוף המילה המאותרת הקודמת עד תחילת המאותרת הבאה.
      var prevEnd = 0;
      for (var i = 0; i < words.length; i++) {
        final located = locatedStarts[i];
        int startRel;
        int endRel;
        if (located != null) {
          startRel = located;
          endRel = located + words[i].length;
          prevEnd = endRel;
        } else {
          startRel = prevEnd;
          endRel = folded.length;
          for (var j = i + 1; j < words.length; j++) {
            if (locatedStarts[j] != null) {
              endRel = locatedStarts[j]!;
              break;
            }
          }
        }
        spans.add(QueryWordSpan(
            words[i], index, match.start + startRel, match.start + endRel));
        index++;
      }
    }
    return spans;
  }

  /// אימות state פר-מילה משוחזר (סשן/היסטוריה) מול הפיצול הנוכחי:
  /// המפות נבנו על `splitQueryWords` של הגרסה ששמרה אותן, ואם חוקי
  /// הפיצול השתנו מאז (למשל `רמב"ם` שהפך משתי מילים לאחת) המפתחות
  /// נופלים בשקט או זולגים למילה הלא-נכונה. מחזיר true כשכל המפתחות
  /// עקביים עם הפיצול הנוכחי של השאילתה.
  static bool restoredPerWordStateMatches(
    String query, {
    Map<String, Map<String, bool>> searchOptions = const {},
    Map<int, List<String>> alternativeWords = const {},
    Map<String, String> spacingValues = const {},
  }) {
    final words = splitQueryWords(query);
    for (final key in searchOptions.keys) {
      final sep = key.lastIndexOf('_');
      if (sep <= 0) return false;
      final word = key.substring(0, sep);
      final index = int.tryParse(key.substring(sep + 1));
      if (index == null ||
          index < 0 ||
          index >= words.length ||
          words[index] != word) {
        return false;
      }
    }
    for (final index in alternativeWords.keys) {
      if (index < 0 || index >= words.length) return false;
    }
    for (final key in spacingValues.keys) {
      final parts = key.split('-');
      if (parts.length != 2) return false;
      final from = int.tryParse(parts[0]);
      final to = int.tryParse(parts[1]);
      if (from == null || to == null || to != from + 1 || to >= words.length) {
        return false;
      }
    }
    return true;
  }

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
