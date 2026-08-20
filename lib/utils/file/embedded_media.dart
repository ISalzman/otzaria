/// מדיה מוטמעת בטקסט הספר — סוגי התמונות הנתמכים והתקרות שלהם.
///
/// **מקור יחיד** לארבעת הממירים: מפה שנכתבת פעמיים נוטה להיסתר, ואז אותה
/// תמונה מוטמעת מ-ODT ומדולגת בשקט מ-DOCX.
library;

/// טיפוס ה-MIME של תמונה לפי סיומת הנתיב, או `null` אם אינה תמונה נתמכת.
String? imageMimeForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  return null;
}

/// תקרות להטמעת מדיה בטקסט הספר.
///
/// תמונה מוטמעת נכנסת ל-HTML כ-data URI — כלומר ל-RAM, למטמון ההמרות
/// ולאינדקס, אחרי ניפוח של פי 4/3 ב-base64. מסמך עם עשרות תמונות בגודל מלא
/// מפיל את ההמרה בזיכרון. חריגה מדלגת על התמונה ומשאירה `<img>` ריק, כדי
/// שמבנה השורות — ועמו מיקומי ההערות והסימניות — יישמר.
class EmbeddedMediaLimits {
  /// תמונה בודדת שגדולה מכך אינה מוטמעת.
  static const int maxImageBytes = 4 * 1024 * 1024;

  /// סך המדיה המוטמעת במסמך אחד.
  static const int maxTotalImageBytes = 32 * 1024 * 1024;

  /// תקרה מוגדלת לתמונת כריכה — כריכות סרוקות כבדות במיוחד, ויש רק אחת.
  static const int maxCoverBytes = 10 * 1024 * 1024;
}
