import 'system_font_locator_stub.dart'
    if (dart.library.io) 'system_font_locator_io.dart'
    as impl;

/// מאתר את קבצי הגופנים (ttf/otf) המותקנים במערכת.
///
/// בדסקטופ: סריקת תיקיות הגופנים המוכרות, ובווינדוס גם רישום ה-registry —
/// שמכסה גופנים שמותקנים מחוץ לתיקיות (למשל הגופנים הפרטיים של Office).
/// ב-web מוחזרת רשימה ריקה.
class SystemFontLocator {
  SystemFontLocator._();

  static List<String> installedFontPaths() => impl.installedFontPaths();
}
