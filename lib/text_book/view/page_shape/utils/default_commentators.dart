import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';

/// מחלקה לניהול ברירות מחדל של מפרשים לפי סוג הספר
/// ההגדרות נטענות מקובץ JSON חיצוני
class DefaultCommentators {
  /// מחזיר מפרשי ברירת מחדל לפי קטגוריית הספר
  /// מקבל גם את רשימת הקישורים כדי למצוא את השמות המלאים של המפרשים
  static Future<Map<String, String?>> getDefaults(TextBook book,
      {List<Link>? links}) async {
    final config = await _loadConfig();

    // קבלת נתיב הספר
    final titleToPath = await FileSystemData.instance.titleToPath;
    var bookPath = titleToPath[book.title] ?? '';

    // נסיון לקבלת נתיב מתוך אובייקט הספר (עבור ספרים ממסד הנתונים)
    if (bookPath.isEmpty) {
      bookPath = book.category?.path ?? book.categoryPath ?? '';
      debugPrint('DefaultCommentators: Used book.category path: "$bookPath"');
    }

    // קבלת שמות המפרשים מה-JSON
    final defaults = _getDefaultsFromConfig(config, book.title, bookPath);

    // אם יש links, נחפש את השמות המלאים של המפרשים
    if (links != null && links.isNotEmpty) {
      debugPrint(
          'DefaultCommentators: Resolving defaults for ${book.title} (path: $bookPath)');
      debugPrint('DefaultCommentators: Raw defaults from config: $defaults');
      return _resolveCommentatorNames(defaults, links);
    }

    return defaults;
  }

  /// מחפש את השמות המלאים של המפרשים מתוך רשימת הקישורים
  static Map<String, String?> _resolveCommentatorNames(
      Map<String, String?> defaults, List<Link> links) {
    // קבלת רשימת שמות המפרשים הזמינים
    final availableLinks = links.where((link) =>
        link.connectionType == 'commentary' || link.connectionType == 'targum');

    final availableCommentators = availableLinks
        .map((link) => utils.getTitleFromPath(link.path2))
        .toSet()
        .toList();

    debugPrint(
        'DefaultCommentators: Available links count: ${availableLinks.length}');
    debugPrint(
        'DefaultCommentators: First 5 available commentators: ${availableCommentators.take(5).toList()}');
    if (availableLinks.isNotEmpty) {
      debugPrint(
          'DefaultCommentators: Sample link path2: ${availableLinks.first.path2}');
    }

    return {
      'right':
          _findMatchingCommentator(defaults['right'], availableCommentators),
      'left': _findMatchingCommentator(defaults['left'], availableCommentators),
      'bottom':
          _findMatchingCommentator(defaults['bottom'], availableCommentators),
      'bottomRight': _findMatchingCommentator(
          defaults['bottomRight'], availableCommentators),
    };
  }

  /// מחפש מפרש שמתאים לשם הנתון
  /// מחזיר את השם המלא אם נמצא, או null אם לא
  static String? _findMatchingCommentator(
      String? shortName, List<String> available) {
    if (shortName == null) return null;

    debugPrint('DefaultCommentators: Searching for "$shortName"');

    // 1. התאמה מדויקת
    String? match = available.firstWhereOrNull((name) => name == shortName);
    if (match != null) {
      debugPrint('DefaultCommentators: Found exact match: "$match"');
      return match;
    }

    // 2. התאמה של התחלה
    match = available.firstWhereOrNull((name) => name.startsWith(shortName));
    if (match != null) {
      debugPrint('DefaultCommentators: Found startsWith match: "$match"');
      return match;
    }

    // 3. התאמה של הכלה
    match = available.firstWhereOrNull((name) => name.contains(shortName));
    if (match != null) {
      debugPrint('DefaultCommentators: Found contains match: "$match"');
      return match;
    }

    // 4. התאמה הפוכה - אם השם בהגדרות הוא נתיב מלא והשם הזמין הוא רק הכותרת
    // נבדוק אם השם בהגדרות מכיל את השם הזמין
    match = available.firstWhereOrNull((name) => shortName.contains(name));
    if (match != null) {
      debugPrint(
          'DefaultCommentators: Found reverse contains match (config contains available): "$match"');
      return match;
    }

    debugPrint('DefaultCommentators: No match found for "$shortName"');
    return null;
  }

  static Future<Map<String, dynamic>> _loadConfig() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/default_commentators.json');
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e, s) {
      debugPrint('Failed to load default commentators config: $e\n$s');
      return {
        'categories': [],
        'default': {
          'right': null,
          'left': null,
          'bottom': null,
          'bottomRight': null,
        }
      };
    }
  }

  static Map<String, String?> _getDefaultsFromConfig(
      Map<String, dynamic> config, String bookTitle, String bookPath) {
    final categories = config['categories'] as List<dynamic>;

    for (final category in categories) {
      if (_matchesCategory(bookPath, category as Map<String, dynamic>)) {
        return _parseCommentators(
            category['commentators'] as Map<String, dynamic>, bookTitle);
      }
    }

    final defaultConfig = config['default'] as Map<String, dynamic>;
    return _parseCommentators(defaultConfig, bookTitle);
  }

  static bool _matchesCategory(String bookPath, Map<String, dynamic> category) {
    // pathContains - כל המחרוזות חייבות להיות בנתיב (AND)
    if (category.containsKey('pathContains')) {
      final pathContains = category['pathContains'] as List<dynamic>;
      if (!pathContains.every((p) => bookPath.contains(p as String))) {
        return false;
      }
    }

    // pathContainsAny - לפחות מחרוזת אחת חייבת להיות בנתיב (OR)
    if (category.containsKey('pathContainsAny')) {
      final pathContainsAny = category['pathContainsAny'] as List<dynamic>;
      if (!pathContainsAny.any((p) => bookPath.contains(p as String))) {
        return false;
      }
    }

    // pathNotContains - אף מחרוזת לא יכולה להיות בנתיב
    if (category.containsKey('pathNotContains')) {
      final pathNotContains = category['pathNotContains'] as List<dynamic>;
      if (pathNotContains.any((p) => bookPath.contains(p as String))) {
        return false;
      }
    }

    return true;
  }

  static Map<String, String?> _parseCommentators(
      Map<String, dynamic> commentators, String bookTitle) {
    return {
      'right': _replaceBookTitle(commentators['right'] as String?, bookTitle),
      'left': _replaceBookTitle(commentators['left'] as String?, bookTitle),
      'bottom': _replaceBookTitle(commentators['bottom'] as String?, bookTitle),
      'bottomRight':
          _replaceBookTitle(commentators['bottomRight'] as String?, bookTitle),
    };
  }

  static String? _replaceBookTitle(String? template, String bookTitle) {
    if (template == null) return null;
    return template.replaceAll('{bookTitle}', bookTitle);
  }
}
