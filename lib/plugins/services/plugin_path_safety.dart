import 'dart:io';

import 'package:path/path.dart' as p;

/// מחזירה את הנתיב הקנוני של [path] (מוחלט, מנורמל ועם symlinks פתורים),
/// או `null` אם לא ניתן לפתור אותו.
///
/// אם [path] עצמו אינו קיים (למשל יעד כתיבה חדש ב-`download`/`extractZip`),
/// פותרת בצורה קנונית את האב הקיים הקרוב ביותר ומצרפת אליו את הסיומת שטרם
/// נוצרה — כך גם נתיב חדש שעובר דרך symlink מאותר לפי יעדו האמיתי. זהו גבול
/// האבטחה לכל פעולות הכתיבה/מחיקה לדיסק של תוספים: בדיקה לקסיקלית על המחרוזת
/// בלבד הייתה מאשרת כתיבה מחוץ ליעד דרך symlink-תיקייה קיים.
String? canonicalizeNearestExisting(String path) {
  var existing = p.normalize(p.absolute(path));
  final pending = <String>[];
  while (FileSystemEntity.typeSync(existing) == FileSystemEntityType.notFound) {
    final parent = p.dirname(existing);
    if (parent == existing) return null; // הגענו לשורש ושום דבר לא קיים
    pending.insert(0, p.basename(existing));
    existing = parent;
  }
  try {
    final isDir =
        FileSystemEntity.typeSync(existing) == FileSystemEntityType.directory;
    final canonical = isDir
        ? Directory(existing).resolveSymbolicLinksSync()
        : File(existing).resolveSymbolicLinksSync();
    return pending.isEmpty
        ? canonical
        : p.normalize(p.joinAll([canonical, ...pending]));
  } catch (_) {
    return null;
  }
}
