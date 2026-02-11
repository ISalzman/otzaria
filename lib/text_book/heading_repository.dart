import 'dart:convert';
import 'package:otzaria/data/models/isar/detected_heading.dart';
import 'package:otzaria/models/heading.dart';
import 'package:otzaria/text_book/heading_detector.dart';
import 'package:otzaria/utils/settings_wrapper.dart';

/// Repository לניהול כותרות בספרים
///
/// משתמש ב-SharedPreferences לשמירה במקום Isar
class HeadingRepository {
  final SettingsWrapper settings;
  final HeadingDetector detector;

  static const String _keyPrefix = 'detected_headings_';

  HeadingRepository({
    required this.settings,
    HeadingDetector? detector,
  }) : detector = detector ?? HeadingDetector();

  /// מחזיר את המפתח לשמירת כותרות של ספר
  String _getKey(int bookId) => '$_keyPrefix$bookId';

  /// מזהה כותרות מתוכן הספר ושומר אותן
  ///
  /// [bookId] - מזהה הספר
  /// [content] - תוכן הספר (HTML או Markdown)
  /// [maxWords] - מספר מילים מקסימלי לכותרת
  /// [headingLevel] - רמת הכותרת
  /// [isMarkdown] - האם התוכן הוא Markdown
  ///
  /// מחזיר רשימת כותרות שזוהו
  Future<List<Heading>> detectAndSaveHeadings({
    required int bookId,
    required String content,
    int maxWords = 20,
    int headingLevel = 6,
    bool isMarkdown = false,
  }) async {
    // זהה כותרות
    final headings = isMarkdown
        ? detector.detectFromMarkdown(
            content,
            maxWords: maxWords,
            headingLevel: headingLevel,
          )
        : detector.detectFromBoldText(
            content,
            maxWords: maxWords,
            headingLevel: headingLevel,
          );

    // שמור במסד נתונים
    await saveHeadings(bookId, headings);

    return headings;
  }

  /// שומר כותרות
  ///
  /// [bookId] - מזהה הספר
  /// [headings] - רשימת כותרות לשמירה
  Future<void> saveHeadings(int bookId, List<Heading> headings) async {
    final detectedHeadings =
        headings.map((h) => DetectedHeading.fromHeading(h, bookId)).toList();

    // הוסף IDs אם אין
    for (int i = 0; i < detectedHeadings.length; i++) {
      detectedHeadings[i].id ??= i;
    }

    final json = jsonEncode(
      detectedHeadings.map((dh) => dh.toJson()).toList(),
    );

    await settings.setValue(_getKey(bookId), json);
  }

  /// מחזיר את כל הכותרות של ספר
  ///
  /// [bookId] - מזהה הספר
  /// [source] - סינון לפי מקור (אופציונלי)
  Future<List<Heading>> getHeadingsForBook(
    int bookId, {
    HeadingSource? source,
  }) async {
    final json = settings.getValue<String>(_getKey(bookId), defaultValue: '[]');

    if (json.isEmpty || json == '[]') {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(json);
      final detectedHeadings = list
          .map((item) => DetectedHeading.fromJson(item as Map<String, dynamic>))
          .toList();

      var headings = detectedHeadings.map((dh) => dh.toHeading()).toList();

      if (source != null) {
        headings = headings.where((h) => h.source == source).toList();
      }

      // מיין לפי מיקום
      headings.sort((a, b) => a.position.compareTo(b.position));

      return headings;
    } catch (e) {
      return [];
    }
  }

  /// מוחק כותרת לפי מזהה
  ///
  /// [headingId] - מזהה הכותרת
  /// [bookId] - מזהה הספר
  Future<void> deleteHeading(int bookId, int headingId) async {
    final headings = await _loadDetectedHeadings(bookId);
    headings.removeWhere((h) => h.id == headingId);
    await _saveDetectedHeadings(bookId, headings);
  }

  /// מוחק את כל הכותרות האוטומטיות של ספר
  ///
  /// [bookId] - מזהה הספר
  Future<void> clearAutoDetectedHeadings(int bookId) async {
    final headings = await _loadDetectedHeadings(bookId);
    headings.removeWhere((h) => h.source == HeadingSource.automatic);
    await _saveDetectedHeadings(bookId, headings);
  }

  /// מוחק את כל הכותרות של ספר
  ///
  /// [bookId] - מזהה הספר
  Future<void> clearAllHeadings(int bookId) async {
    await settings.remove(_getKey(bookId));
  }

  /// ממיר כותרת אוטומטית לידנית
  ///
  /// [bookId] - מזהה הספר
  /// [headingId] - מזהה הכותרת
  Future<void> convertToManual(int bookId, int headingId) async {
    final headings = await _loadDetectedHeadings(bookId);
    final index = headings.indexWhere((h) => h.id == headingId);

    if (index != -1) {
      headings[index].source = HeadingSource.manual;
      await _saveDetectedHeadings(bookId, headings);
    }
  }

  /// מעדכן רמת כותרת
  ///
  /// [bookId] - מזהה הספר
  /// [headingId] - מזהה הכותרת
  /// [newLevel] - רמה חדשה (1-6)
  Future<void> updateHeadingLevel(
      int bookId, int headingId, int newLevel) async {
    if (newLevel < 1 || newLevel > 6) {
      throw ArgumentError('רמת כותרת חייבת להיות בין 1 ל-6');
    }

    final headings = await _loadDetectedHeadings(bookId);
    final index = headings.indexWhere((h) => h.id == headingId);

    if (index != -1) {
      headings[index].level = newLevel;
      await _saveDetectedHeadings(bookId, headings);
    }
  }

  /// בודק אם יש כותרות שמורות לספר
  ///
  /// [bookId] - מזהה הספר
  Future<bool> hasHeadings(int bookId) async {
    final headings = await getHeadingsForBook(bookId);
    return headings.isNotEmpty;
  }

  /// מחזיר מספר כותרות לפי מקור
  ///
  /// [bookId] - מזהה הספר
  Future<Map<HeadingSource, int>> getHeadingCountBySource(int bookId) async {
    final headings = await getHeadingsForBook(bookId);
    final counts = <HeadingSource, int>{};

    for (final source in HeadingSource.values) {
      counts[source] = headings.where((h) => h.source == source).length;
    }

    return counts;
  }

  /// טוען כותרות מ-SharedPreferences
  Future<List<DetectedHeading>> _loadDetectedHeadings(int bookId) async {
    final json = settings.getValue<String>(_getKey(bookId), defaultValue: '[]');

    if (json.isEmpty || json == '[]') {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(json);
      return list
          .map((item) => DetectedHeading.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// שומר כותרות ל-SharedPreferences
  Future<void> _saveDetectedHeadings(
    int bookId,
    List<DetectedHeading> headings,
  ) async {
    final json = jsonEncode(
      headings.map((dh) => dh.toJson()).toList(),
    );
    await settings.setValue(_getKey(bookId), json);
  }
}
