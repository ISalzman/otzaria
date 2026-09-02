import 'dart:isolate';

import 'package:archive/archive_io.dart';

/// מחלץ ארכיון (zip/tar) מ-[archivePath] אל [outputDir] ב-isolate נפרד.
///
/// `extractFileToDisk` מוצהרת `async` אך קוראת וכותבת סינכרונית בלולאה, ולכן
/// על ה-isolate הראשי היא חוסמת את לולאת ההודעות עד כדי ANR באנדרואיד.
/// היא מקבלת נתיבים ולא בייטים, כך שמעבר ל-isolate אינו מעתיק נתונים.
Future<void> extractArchiveFileToDisk(String archivePath, String outputDir) =>
    Isolate.run(() => extractFileToDisk(archivePath, outputDir));
