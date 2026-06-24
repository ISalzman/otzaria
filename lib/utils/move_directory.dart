import 'dart:io';
import 'package:path/path.dart' as p;

/// Moves all contents of [source] directory to [destination].
/// Copies everything first; deletes source only after a successful copy.
///
/// Returns null on full success.
/// Returns [source] path if deletion failed — caller should warn the user to
/// delete manually, but the path update should still proceed.
Future<String?> moveDirectory(String source, String destination) async {
  final sourceDir = Directory(source);
  if (!await sourceDir.exists()) {
    throw Exception('תיקיית המקור לא קיימת: $source');
  }

  if (p.equals(source, destination)) return null;

  // Guard: destination must not be inside source (would create infinite loop).
  if (p.isWithin(source, destination)) {
    throw Exception('תיקיית היעד לא יכולה להיות בתוך תיקיית המקור');
  }

  final destDir = Directory(destination);
  if (!await destDir.exists()) {
    await destDir.create(recursive: true);
  }

  await _copyDirectoryContents(source, destination);

  try {
    await sourceDir.delete(recursive: true);
    return null; // success
  } catch (_) {
    // Full directory deletion failed (e.g. needs admin on ProgramData).
    // Try deleting just the contents — leave the empty directory behind.
    try {
      await _deleteDirectoryContents(source);
      return null; // contents gone, empty directory remains — acceptable
    } catch (_) {
      // Even contents could not be deleted; let caller warn user.
      return source;
    }
  }
}

Future<void> _deleteDirectoryContents(String path) async {
  await for (final entity in Directory(path).list()) {
    await entity.delete(recursive: true);
  }
}

Future<void> _copyDirectoryContents(String source, String destination) async {
  await for (final entity in Directory(source).list()) {
    final name = p.basename(entity.path);
    final destPath = p.join(destination, name);
    if (entity is File) {
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      await entity.copy(destPath);
    } else if (entity is Directory) {
      await _copyDirectoryContents(entity.path, destPath);
    }
  }
}
