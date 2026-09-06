import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/windowing/thread_contention_probe.dart';

/// המדידה עצמה דורשת שני חלונות חיים ואינה ניתנת לכיסוי כאן. מה שכן חייב
/// כיסוי הוא הגידור: בקשה שמקפיאה חלון אחר אסור שתהיה נגישה בבנייה רגילה.
void main() {
  test('המדידה מושבתת בלי משתנה הסביבה', () {
    // ⚠️ הבדיקה מאמתת את ברירת המחדל, כי `Platform.environment` אינו
    // ניתן להזרקה. אם היא נכשלת אצל מישהו — הוא הריץ עם
    // OTZARIA_MEASURE_CONTENTION=1 דלוק, וזו עצמה תשובה שימושית.
    expect(ThreadContentionProbe.isEnabled, isFalse);
  });

  test('burnCpu חוסם באמת, ולא מוותר על ה-thread', () {
    // ⚠️ זו כל הנקודה. `Future.delayed` בלולאה היה משחרר את ה-thread בין
    // איטרציות — כלומר מודד בדיוק את מה שאינו שובר. מה שמקפיא חלון אחר
    // הוא קוד Dart שאינו מוותר.
    final started = DateTime.now();
    ThreadContentionProbe.burnCpu(120);
    final elapsed = DateTime.now().difference(started).inMilliseconds;

    expect(elapsed, greaterThanOrEqualTo(120));
    // תקרה רחבה: הלולאה בודקת את השעון רק כל 100,000 איטרציות, ומכונה
    // עמוסה יכולה לחרוג. הכשל שמעניין הוא "חזר מיד", לא "חזר באיחור".
    expect(elapsed, lessThan(3000));
  });
}
