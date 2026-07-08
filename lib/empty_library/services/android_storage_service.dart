import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// מיקום אחסון אפשרי לספרייה ב-Android.
///
/// [libraryRoot] הוא שורש הספרייה שיישמר; `null` פירושו אחסון פנימי (ברירת
/// מחדל). מיקומים חיצוניים (כרטיס SD) הם תיקיית האפליקציה הייעודית על הכרך,
/// שנגישה ל-sqlite3 native ואינה דורשת הרשאות.
@immutable
class AndroidStorageOption {
  final String label;
  final String? libraryRoot;
  final int freeBytes;
  final bool isRemovable;

  const AndroidStorageOption({
    required this.label,
    required this.libraryRoot,
    required this.freeBytes,
    required this.isRemovable,
  });
}

/// גילוי מיקומי אחסון זמינים ב-Android עבור בחירת מיקום הספרייה בהתקנה.
class AndroidStorageService {
  const AndroidStorageService._();

  /// מחזיר את מיקומי האחסון הזמינים. כשאין כרטיס SD (אין ברירה אמיתית) —
  /// מחזיר רשימה ריקה, וה-UI לא מציג בורר.
  static Future<List<AndroidStorageOption>> listStorageOptions() async {
    if (!Platform.isAndroid) return const [];

    final internalDir = await getApplicationDocumentsDirectory();
    final externals = await getExternalStorageDirectories() ?? const [];

    // כרך פנימי מזוהה לפי /storage/emulated/ (אחסון משותף על המכשיר עצמו).
    // כל כרך אחר הוא נשלף — כרטיס SD או USB.
    final removable =
        externals.where((d) => !d.path.contains('/storage/emulated/')).toList();
    if (removable.isEmpty) return const [];

    final options = <AndroidStorageOption>[
      AndroidStorageOption(
        label: 'אחסון פנימי',
        libraryRoot: null,
        freeBytes: await _freeBytes(internalDir.path),
        isRemovable: false,
      ),
    ];
    for (final dir in removable) {
      options.add(AndroidStorageOption(
        label: 'כרטיס SD',
        libraryRoot: dir.path,
        freeBytes: await _freeBytes(dir.path),
        isRemovable: true,
      ));
    }
    return options;
  }

  /// מקום פנוי בבייטים לנתיב נתון, או -1 אם לא ניתן לקבוע. משתמש ב-df,
  /// הנתמך גם ב-toybox של Android; הדגל -k (בלוקים של 1024B) נייד בין המימושים.
  static Future<int> _freeBytes(String dirPath) async {
    try {
      final result =
          await Process.run('df', ['-k', dirPath], runInShell: false);
      if (result.exitCode != 0) return -1;
      final lines = result.stdout.toString().trim().split('\n');
      if (lines.length < 2) return -1;
      final parts = lines.last.trim().split(RegExp(r'\s+'));
      if (parts.length < 4) return -1;
      final availableKb = int.tryParse(parts[3]);
      return availableKb == null ? -1 : availableKb * 1024;
    } catch (_) {
      return -1;
    }
  }
}
