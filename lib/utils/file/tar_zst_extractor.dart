import 'dart:io';

import 'package:otzaria/utils/file/archive_extractor.dart';
import 'package:otzaria/utils/file/zstd_stream_extractor.dart';

/// מחלץ ארכיון tar.zst לתיקיית היעד בזרימה נמוכת-זיכרון: חילוץ ה-zst לקובץ
/// tar זמני, ואז פריסת ה-tar בזרימה מהקובץ.
Future<void> extractTarZstToDir(
  String archivePath,
  String outputDir, {
  void Function(double progress)? onProgress,
}) async {
  final tarPath = '$archivePath.tar';
  try {
    await ZstdStreamExtractor.extractToFile(
      archivePath,
      tarPath,
      onProgress: onProgress,
    );
    await extractArchiveFileToDisk(tarPath, outputDir);
  } finally {
    // גם חילוץ zst שנכשל באמצע משאיר tar חלקי — מנקים תמיד.
    await File(tarPath).delete().catchError((_) => File(tarPath));
  }
}
