import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/windowing/app_window_id.dart';
import 'package:otzaria/core/windowing/last_active_window.dart';

/// קישורי עומק והעברת טאב בין חלונות צריכים לדעת לאיזה חלון לפנות כשאין
/// חלון פעיל. עד עכשיו לא היה מקור לנתון הזה כלל.
void main() {
  tearDown(LastActiveWindow.resetForTest);

  test('ברירת המחדל היא החלון הראשי', () {
    expect(LastActiveWindow.id, AppWindowId.primary);
  });

  test('markActive מעדכן את המזהה', () {
    LastActiveWindow.markActive(const AppWindowId('window-2'));
    expect(LastActiveWindow.id, const AppWindowId('window-2'));
  });

  test('קריאה חוזרת עם אותו מזהה אינה משנה דבר', () {
    LastActiveWindow.markActive(const AppWindowId('window-2'));
    LastActiveWindow.markActive(const AppWindowId('window-2'));
    expect(LastActiveWindow.id, const AppWindowId('window-2'));
  });

  test('החלון האחרון גובר על הקודמים', () {
    LastActiveWindow.markActive(const AppWindowId('window-2'));
    LastActiveWindow.markActive(const AppWindowId('window-3'));
    expect(LastActiveWindow.id, const AppWindowId('window-3'));
  });
}
