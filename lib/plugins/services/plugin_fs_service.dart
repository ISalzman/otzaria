import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// שירות פעולות קבצים עבור גשר התוספים: חילוץ ZIP ומחיקת קובץ.
///
/// משמש את ה-RPC `fs.extractZip` ו-`fs.deleteFile`. כל הפעולות מתבצעות בצד
/// אוצריא (Flutter), מכיוון שה-WebView של התוסף נטען מ-origin `file://` ואינו
/// יכול לכתוב/למחוק בדיסק.
///
/// **גבול אבטחה:** השירות מבצע את הפעולה על הנתיב שמועבר אליו כפי שהוא.
/// האחריות לוודא שהנתיב נמצא בתוך תיקייה שהמשתמש אישר במפורש (דרך
/// `ui.pickFolder`) מוטלת על הקורא — `PluginBridgeAdapter`. בנוסף,
/// [extractZip] אוכף תקרות גודל ומספר רשומות ומדלג על רשומות שיוצאות מתיקיית
/// היעד (path-traversal) או על symlinks.
class PluginFsService {
  /// תקרת הגודל הכולל (לא דחוס) שמותר לחלץ. חילוץ שחורג ממנה נקטע
  /// ב-`error.too_large` — הגנת zip bomb (ארכיון דחוס קטן שמתרחב לגיגה-בייטים).
  final int maxUncompressedBytes;

  /// תקרת מספר הרשומות בארכיון. חוסמת ארכיון עם המוני רשומות זעירות.
  final int maxEntries;

  PluginFsService({
    this.maxUncompressedBytes = 2 * 1024 * 1024 * 1024,
    this.maxEntries = 50000,
  });

  /// מחלצת את ארכיון ה-ZIP שב-[zipPath] אל [destFolder].
  ///
  /// יוצרת את [destFolder] אם אינה קיימת. החילוץ מתבצע ב-streaming רשומה-רשומה
  /// (ללא טעינת הארכיון כולו לזיכרון), כשבכל רשומה נאכפות התקרות
  /// [maxUncompressedBytes] ו-[maxEntries] — כך תוסף לא-מהימן אינו יכול למלא
  /// את הדיסק או לתקוע את ה-RPC עם zip bomb.
  ///
  /// זורקת [Exception] אם הקובץ ב-[zipPath] אינו קיים, אם החילוץ נכשל, או
  /// `error.too_large` אם הארכיון חורג מאחת התקרות.
  Future<void> extractZip(String zipPath, String destFolder) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw Exception('error.not_found: zip file does not exist');
    }
    await Directory(destFolder).create(recursive: true);

    final canonicalDest = p.canonicalize(destFolder);
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      var entryCount = 0;
      var totalBytes = 0;
      for (final file in archive) {
        if (++entryCount > maxEntries) {
          throw Exception('error.too_large: archive has too many entries');
        }

        final outPath = p.join(destFolder, p.normalize(file.name));
        // הגנת path-traversal: רשומה עם `../` או symlink לא תיכתב מחוץ ליעד.
        if (!p.isWithin(canonicalDest, p.canonicalize(outPath))) {
          continue;
        }
        if (file.isSymbolicLink) {
          continue;
        }
        if (file.isDirectory) {
          await Directory(outPath).create(recursive: true);
          continue;
        }

        // בדיקה מקדימה לפי הגודל המוצהר — חוסמת קובץ ענק עוד לפני כתיבתו.
        if (totalBytes + file.size > maxUncompressedBytes) {
          throw Exception('error.too_large: extracted size exceeds limit');
        }
        final output = OutputFileStream(outPath);
        try {
          file.writeContent(output);
        } finally {
          await output.close();
        }
        // הגודל המוצהר עלול לשקר; סופרים את מה שנכתב בפועל ובודקים שוב.
        totalBytes += output.length;
        if (totalBytes > maxUncompressedBytes) {
          throw Exception('error.too_large: extracted size exceeds limit');
        }
      }
    } finally {
      await input.close();
    }
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
