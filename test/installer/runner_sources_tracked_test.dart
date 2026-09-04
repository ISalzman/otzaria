import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// כל קובץ מקור שה-runner מקמפל חייב להיות **במאגר**.
///
/// ⚠️ `.gitignore` מסנן את `windows/runner/*` במלואו, וכל קובץ נשמר רק
/// בחריגה מפורשת (`!windows/runner/<name>`). קובץ שכבר tracked ממשיך
/// להיות tracked ולכן הבעיה אינה נראית — אבל קובץ **חדש** נבלע בשקט:
/// `git add -A` מדלג עליו בלי מילה, ה-CMakeLists כן מזכיר אותו, וכל מי
/// שיעשה clone מקבל `Cannot find source file`.
///
/// זה קרה בפועל ל-`drag_preview_window.cpp` — 177 שורות של תצוגת הגרירה
/// הנייטיבית שהיו בעץ העבודה בלבד. הבנייה עבדה מקומית וכל דחיפה הייתה
/// שוברת את הענף אצל כולם.
void main() {
  test('כל מקור ב-CMakeLists של ה-runner קיים על הדיסק ואינו מסונן', () {
    final root = _repoRoot();
    final cmake = File('${root.path}/windows/runner/CMakeLists.txt');
    if (!cmake.existsSync()) {
      // עץ בלי הצד הנייטיב של Windows — אין מה לבדוק.
      return;
    }

    final sources = _executableSources(cmake.readAsStringSync());
    expect(
      sources,
      isNotEmpty,
      reason: 'לא נמצאו מקורות ב-add_executable — הפורמט השתנה, עדכן את הבדיקה',
    );

    final missing = <String>[];
    final ignored = <String>[];
    for (final source in sources) {
      // נתיבים עם משתני CMake (למשל generated_plugin_registrant) אינם
      // חלק מהמאגר ומדולגים.
      if (source.contains(r'${')) continue;
      final file = File('${root.path}/windows/runner/$source');
      if (!file.existsSync()) {
        missing.add(source);
        continue;
      }
      if (_isGitIgnored(root, 'windows/runner/$source')) ignored.add(source);
    }

    expect(missing, isEmpty, reason: 'מקורות שה-CMakeLists מזכיר ואינם קיימים');
    expect(
      ignored,
      isEmpty,
      reason:
          'מקורות שקיימים אבל מסוננים ב-.gitignore. הוסף '
          '`!windows/runner/<name>` — אחרת clone יקבל כשל בנייה',
    );
  });
}

/// שמות הקבצים שבתוך בלוק `add_executable(...)`.
List<String> _executableSources(String cmake) {
  final start = cmake.indexOf('add_executable(');
  if (start < 0) return const [];
  final end = cmake.indexOf(')', start);
  if (end < 0) return const [];
  final block = cmake.substring(start, end);
  return RegExp(
    r'"([^"]+)"',
  ).allMatches(block).map((m) => m.group(1)!).toList();
}

/// ⚠️ `git check-ignore` ולא פירוש עצמאי של `.gitignore`. כלל האללווליסט
/// כאן (`windows/runner/*` ואחריו `!`) הוא בדיוק המקום שבו פירוש ידני
/// טועה, וטעות כזו תהפוך את הבדיקה לירוקה-תמיד.
bool _isGitIgnored(Directory root, String path) {
  try {
    final result = Process.runSync('git', [
      'check-ignore',
      '-q',
      path,
    ], workingDirectory: root.path);
    // 0 = מסונן, 1 = אינו מסונן, 128 = לא מאגר git. רק 0 הוא כשל.
    return result.exitCode == 0;
  } on ProcessException {
    // ⚠️ `runSync` **זורק** כשההרצה עצמה נכשלת (אין git ב-PATH), ואינו
    // מחזיר קוד יציאה. סביבה בלי git אינה יכולה לבדוק את הכלל הזה, וזו
    // אינה סיבה להפיל את הבדיקה.
    return false;
  }
}

Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    dir = dir.parent;
  }
  return Directory.current;
}
