import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// שומר קובץ דרך דיאלוג המערכת ומבטיח שהנתיב מקבל את הסיומת המבוקשת.
///
/// דיאלוג השמירה ב-Windows אינו משלים סיומת לשם שהמשתמש מקליד
/// (file_picker אינו מציב lpstrDefExt), לכן משלימים אותה כאן אחרי הכתיבה.
Future<String?> saveFileWithExtension({
  required String fileName,
  required String extension,
  required Uint8List bytes,
  String? dialogTitle,
  String? initialDirectory,
}) async {
  final path = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    initialDirectory: initialDirectory,
    type: FileType.custom,
    allowedExtensions: [extension],
    bytes: bytes,
    lockParentWindow: true,
  );
  if (path == null) return null;
  return ensureFileExtension(path, extension);
}

/// אם הקובץ שנכתב ב-[path] חסר את הסיומת [extension] — משנה את שמו בהתאם.
///
/// מחזיר את הנתיב הסופי של הקובץ (המקורי אם הסיומת כבר קיימת).
Future<String> ensureFileExtension(String path, String extension) async {
  final suffix = '.${extension.toLowerCase()}';
  if (path.toLowerCase().endsWith(suffix)) return path;

  final file = File(path);
  if (!await file.exists()) return path;

  final target = '$path.$extension';
  final targetFile = File(target);
  if (await targetFile.exists()) {
    await targetFile.delete();
  }
  await file.rename(target);
  return target;
}
