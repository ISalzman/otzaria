import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// מקום פנוי בכונן של נתיב, עם מזהה volume להשוואה בין שני נתיבים.
class DiskSpaceInfo {
  /// מזהה ה-volume: שורש הכונן ב-Windows, שדה ה-filesystem של df ב-POSIX.
  final String? volumeId;

  /// בייטים פנויים, או -1 כשלא ניתן לקבוע.
  final int freeBytes;

  const DiskSpaceInfo({required this.volumeId, required this.freeBytes});

  static const unknown = DiskSpaceInfo(volumeId: null, freeBytes: -1);
}

/// המקום הפנוי בכונן שמכיל את [dirPath]. לעולם לא זורק — כשל בבדיקה מחזיר
/// [DiskSpaceInfo.unknown] והקורא מדלג עליה.
Future<DiskSpaceInfo> getDiskSpaceInfo(String dirPath) async {
  try {
    final existing = _existingAncestor(dirPath);
    return Platform.isWindows
        ? _windowsDiskSpace(existing)
        : await _posixDiskSpace(existing);
  } catch (_) {
    return DiskSpaceInfo.unknown;
  }
}

/// שאילתת המקום הפנוי דורשת נתיב קיים — מטפסים לאב הקיים הקרוב.
String _existingAncestor(String dirPath) {
  var current = p.normalize(p.absolute(dirPath));
  while (!Directory(current).existsSync()) {
    final parent = p.dirname(current);
    if (parent == current) break;
    current = parent;
  }
  return current;
}

DiskSpaceInfo _windowsDiskSpace(String dirPath) {
  final dirPtr = dirPath.toPcwstr();
  final freeBytes = calloc<Uint64>();
  try {
    if (!GetDiskFreeSpaceEx(dirPtr, freeBytes, null, null).value) {
      return DiskSpaceInfo.unknown;
    }
    return DiskSpaceInfo(
      volumeId: p.rootPrefix(dirPath).toUpperCase(),
      freeBytes: freeBytes.value,
    );
  } finally {
    malloc.free(dirPtr);
    calloc.free(freeBytes);
  }
}

/// `df -k` נתמך גם ב-toybox של אנדרואיד וגם ב-coreutils.
Future<DiskSpaceInfo> _posixDiskSpace(String dirPath) async {
  final result = await Process.run('df', ['-k', dirPath], runInShell: false);
  if (result.exitCode != 0) return DiskSpaceInfo.unknown;
  final lines = result.stdout.toString().trim().split('\n');
  if (lines.length < 2) return DiskSpaceInfo.unknown;
  // שורת הנתונים של df -k: Filesystem 1K-blocks Used Available Use% Mount
  final parts = lines.last.trim().split(RegExp(r'\s+'));
  if (parts.length < 4) return DiskSpaceInfo.unknown;
  final availableKb = int.tryParse(parts[3]);
  if (availableKb == null) return DiskSpaceInfo.unknown;
  return DiskSpaceInfo(volumeId: parts[0], freeBytes: availableKb * 1024);
}
