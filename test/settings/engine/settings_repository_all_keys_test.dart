import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';

/// שומר על [SettingsRepository.allKeys] מסונכרן עם המפתחות המוצהרים בקובץ.
///
/// הרשימה משמשת את הגיבוי כרשת ביטחון כשה-Hive box אינו זמין. מפתח חדש
/// שנשמט ממנה נעלם מהגיבוי בשקט — בדיוק הכשל שהפיל את `key-custom-folders`.
void main() {
  const repositoryPath = 'lib/settings/engine/settings_repository.dart';

  /// שמות הקבועים (`keyXxx`) שמוצהרים בקובץ עם ערך מחרוזת.
  /// תופס גם הצהרה שנשברה לשתי שורות ע"י dart format.
  Set<String> declaredConstantNames(String source) {
    final pattern = RegExp(
      r"static const String (key\w+)\s*=\s*\n?\s*'([^']+)'",
      multiLine: true,
    );
    return pattern.allMatches(source).map((m) => m.group(1)!).toSet();
  }

  /// שמות הקבועים שמופיעים בתוך גוף הרשימה `allKeys`.
  Set<String> namesInsideAllKeys(String source) {
    final start = source.indexOf('allKeys = [');
    expect(start, isNot(-1), reason: 'לא נמצאה ההצהרה של allKeys');
    final end = source.indexOf('];', start);
    final body = source.substring(start, end);
    return RegExp(r'\bkey\w+\b')
        .allMatches(body)
        .map((m) => m.group(0)!)
        .where((name) => name != 'keys')
        .toSet();
  }

  late String source;

  setUpAll(() {
    source = File(repositoryPath).readAsStringSync();
  });

  test('allKeys מכיל כל מפתח הגדרות שמוצהר בקובץ', () {
    final declared = declaredConstantNames(source);
    final listed = namesInsideAllKeys(source);

    expect(
      declared.difference(listed),
      isEmpty,
      reason:
          'מפתחות שהוצהרו אך חסרים ב-SettingsRepository.allKeys — '
          'הוסף אותם לרשימה, אחרת הם לא ייכנסו לגיבוי',
    );
  });

  test('allKeys אינו מפנה למפתח שאינו מוצהר עוד', () {
    final declared = declaredConstantNames(source);
    final listed = namesInsideAllKeys(source);

    expect(
      listed.difference(declared),
      isEmpty,
      reason: 'שמות ב-allKeys שאינם קבועי מפתח מוצהרים',
    );
  });

  test('allKeys — הערכים ייחודיים וללא כפילות', () {
    expect(
      SettingsRepository.allKeys.toSet(),
      hasLength(SettingsRepository.allKeys.length),
      reason: 'מפתח מופיע פעמיים ב-allKeys',
    );
  });

  test('allKeys — כל הערכים בפורמט key- ואינם ריקים', () {
    for (final key in SettingsRepository.allKeys) {
      expect(key, isNotEmpty);
      expect(
        key,
        startsWith('key-'),
        reason: 'מפתח הגדרות חייב להתחיל ב-key-: $key',
      );
    }
  });

  test('הרשימה מכסה את המפתחות שנשמטו מהגיבוי לפני התיקון', () {
    // רגרסיה: אלה המפתחות שאיבדו את התיקיות המותאמות בשחזור.
    expect(
      SettingsRepository.allKeys,
      containsAll([
        SettingsRepository.keyCustomFolders,
        SettingsRepository.keyLibraryFolderName,
        SettingsRepository.keyMergeUserBooksIntoLibrary,
      ]),
    );
  });
}
