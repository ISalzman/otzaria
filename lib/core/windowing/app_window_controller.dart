import 'dart:ui';

import 'package:otzaria/core/windowing/app_window_id.dart';
import 'package:window_manager/window_manager.dart' show TitleBarStyle;

/// פעולות ושאילתות על חלון **אחד**.
///
/// היום הכול עובר דרך ה-singleton הגלובלי `windowManager`, שמתאר תמיד את
/// החלון היחיד של התהליך. הממשק הזה הוא ההפרדה בין "החלון" לבין "החלון
/// היחיד": כל קורא מקבל את החלון שלו, ואין דרך לפנות בטעות לחלון אחר.
///
/// המשטח נגזר ממה שהאפליקציה קוראת בפועל — 23 מתודות ב-44 אתרי קריאה,
/// בשבעה קבצים — ולא ממשטח ה-API של `window_manager`. שיטות שאיש אינו
/// קורא, כמו `restore()` ו-`activate()`, אינן כאן בכוונה.
abstract interface class AppWindowController {
  AppWindowId get id;

  Future<void> show();
  Future<void> focus();
  Future<void> minimize();
  Future<void> maximize();
  Future<void> unmaximize();
  Future<void> center();
  Future<void> startDragging();

  /// סגירה מנומסת — עוברת דרך ה-handshake של `onWindowClose`.
  Future<void> close();

  /// הריסה מיידית, בלי handshake. עוקפת את שטיפת הכתיבות התלויות.
  Future<void> destroy();

  Future<bool> isVisible();
  Future<bool> isMaximized();
  Future<bool> isMinimized();
  Future<bool> isFullScreen();
}

/// גודל, מיקום ומצב תצוגה של חלון.
///
/// ממשק נפרד מ-[AppWindowController] משום שהצרכן העיקרי שלו,
/// `WindowPersistence`, הוא מחלקה `static` בלי `BuildContext` — ואילו
/// [AppWindowController] מגיע דרך עץ ה-widgets. הפרדה כאן חוסכת מ-
/// `WindowPersistence` תלות במשטח שאין לו שימוש בו.
abstract interface class AppWindowGeometry {
  Future<Rect> getBounds();
  Future<void> setBounds(Rect bounds);
  Future<void> setSize(Size size);
  Future<void> setMinimumSize(Size size);
  Future<void> setFullScreen(bool value);

  /// ⚠️ [windowButtonVisibility] הוא חלק מהחוזה, לא פרמטר אופציונלי.
  ///
  /// שלושת אתרי הקריאה באפליקציה מעבירים `false` במפורש
  /// (`main.dart`, ושניים ב-`fullscreen_helper.dart`), משום שהאפליקציה
  /// מציירת סרגל כותרת משלה. ברירת מחדל שתשמיט אותו הייתה מחזירה בשקט
  /// את כפתורי המערכת של macOS לצד הכפתורים המותאמים.
  Future<void> setTitleBarStyle(
    TitleBarStyle style, {
    required bool windowButtonVisibility,
  });
}
