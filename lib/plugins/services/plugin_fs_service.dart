import 'dart:io';

import 'package:archive/archive_io.dart';

/// שירות פעולות קבצים עבור גשר התוספים: חילוץ ZIP ומחיקת קובץ.
///
/// משמש את ה-RPC `fs.extractZip` ו-`fs.deleteFile`. כל הפעולות מתבצעות בצד
/// אוצריא (Flutter), מכיוון שה-WebView של התוסף נטען מ-origin `file://` ואינו
/// יכול לכתוב/למחוק בדיסק.
///
/// **גבול אבטחה:** השירות מבצע את הפעולה על הנתיב שמועבר אליו כפי שהוא.
/// האחריות לוודא שהנתיב נמצא בתוך תיקייה שהמשתמש אישר במפורש (דרך
/// `ui.pickFolder`) מוטלת על הקורא — `PluginBridgeAdapter`. בנוסף,
/// [extractZip] מסתמך על הגנת path-traversal המובנית ב-[extractFileToDisk]
/// כדי שרשומות עם `../` לא ייכתבו מחוץ לתיקיית היעד.
class PluginFsService {
  /// מחלצת את ארכיון ה-ZIP שב-[zipPath] אל [destFolder].
  ///
  /// יוצרת את [destFolder] אם אינה קיימת. החילוץ מתבצע ב-streaming דרך
  /// [extractFileToDisk] (אותה פונקציה שאוצריא משתמשת בה לחילוץ ספריות),
  /// כך שאין טעינת הארכיון כולו לזיכרון והגנת ה-path-traversal שלה חלה.
  ///
  /// זורקת [Exception] אם הקובץ ב-[zipPath] אינו קיים או אם החילוץ נכשל.
  Future<void> extractZip(String zipPath, String destFolder) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('error.not_found: zip file does not exist');
    }
    await Directory(destFolder).create(recursive: true);
    await extractFileToDisk(zipPath, destFolder);
  }

  /// מוחקת את הקובץ ב-[path].
  ///
  /// אם הקובץ אינו קיים — מסתיימת בשקט (idempotent), כך שניקוי חוזר אינו
  /// נכשל. אם [path] מצביע על תיקייה — זורקת, מכיוון ש-`fs.deleteFile`
  /// מיועדת לקבצים בלבד.
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return;
    }
    if (await Directory(path).exists()) {
      throw Exception('error.invalid_params: path is a directory');
    }
    // הקובץ אינו קיים — אין מה למחוק, פעולה idempotent ללא שגיאה.
  }
}
