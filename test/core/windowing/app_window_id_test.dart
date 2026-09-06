import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/windowing/app_window_id.dart';

/// המזהה משמש כמפתח ברישומים וכערך שנשמר לדיסק, ולכן שוויון ערך ולא זהות
/// אובייקט הוא החוזה: מזהה שנקרא מקובץ חייב להיות שווה למזהה החי שמתאר
/// את אותו חלון.
void main() {
  test('שוויון לפי ערך, לא לפי זהות אובייקט', () {
    const a = AppWindowId('window-7');
    final b = AppWindowId('window-${7}');

    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const AppWindowId('window-8')));
  });

  test('משמש כמפתח Map — מזהה שנבנה מחדש מוצא את אותה רשומה', () {
    final registry = <AppWindowId, String>{const AppWindowId('window-7'): 'א'};

    expect(registry[AppWindowId('window-${7}')], 'א');
    expect(registry[const AppWindowId('window-8')], isNull);
  });

  test('primary הוא ברירת המחדל של חלון יחיד', () {
    expect(AppWindowId.primary.value, 'window-primary');
    expect(AppWindowId.primary, const AppWindowId('window-primary'));
  });

  test('toString חושף את המזהה בלבד', () {
    expect(const AppWindowId('window-7').toString(), 'AppWindowId(window-7)');
  });
}
