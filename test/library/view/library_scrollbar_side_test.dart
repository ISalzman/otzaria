import 'dart:io';

import 'package:test/test.dart';

/// בדיקה סטטית: מסכי הספרייה מגלגלים ברשימות רגילות, ופס הגלילה האוטומטי של
/// Material נופל בעברית לקצה שמאל. LibraryBrowser תלוי בכל ה-BLoCs של
/// האפליקציה ואינו נבנה בטסט, ולכן הכיסוי כאן הוא על העטיפה עצמה. התנהגות
/// [EdgeScrollbarBehavior] עצמה נבדקת ב-test/widgets/edge_scrollbar_behavior_test.dart.
void main() {
  final source = File(
    'lib/library/view/library_browser.dart',
  ).readAsStringSync();

  test('קובץ הספרייה נקרא — הנתיב תקין', () {
    expect(source, contains('class LibraryBrowser'));
  });

  test('תוכן הספרייה עטוף בפס גלילה בקצה ימין', () {
    expect(
      source,
      contains('EdgeScrollbarBehavior.right()'),
      reason:
          'בלי העטיפה פס הגלילה של עץ הספרייה חוזר לקצה שמאל, הקצה שנפגש '
          'עם חלונית התצוגה המקדימה',
    );
  });

  test('העטיפה חלה על אזור התוכן הראשי (mainContent) של הספרייה', () {
    final mainContentIdx = source.indexOf('mainContent: RepaintBoundary');
    expect(mainContentIdx, greaterThan(-1), reason: 'מבנה mainContent השתנה');

    final block = source.substring(
      mainContentIdx,
      mainContentIdx + 400 > source.length
          ? source.length
          : mainContentIdx + 400,
    );
    expect(
      block,
      contains('EdgeScrollbarBehavior.right()'),
      reason: 'העטיפה אינה על אזור התוכן של הספרייה',
    );
  });

  test('אין עוד מימוש פרטי מקומי של התנהגות פס הגלילה', () {
    // ההתנהגות שוכנת ב-lib/widgets/feedback/edge_scrollbar_behavior.dart
    // ומשותפת לחלונית הצד, לרשת הכלים ולספרייה.
    for (final path in const [
      'lib/library/view/library_browser.dart',
      'lib/widgets/layout/adaptive_side_pane.dart',
      'lib/tools/view/tools_launcher_panel.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('extends MaterialScrollBehavior')),
        reason: '$path מגדיר התנהגות גלילה משלו במקום לחלוק את המשותפת',
      );
    }
  });
}
