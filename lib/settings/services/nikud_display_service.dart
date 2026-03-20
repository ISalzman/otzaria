import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/settings/engine/settings_state.dart';

/// מחזיר האם יש להסיר ניקוד עבור ספר נתון.
///
/// [defaultRemoveNikud] - האם ברירת המחדל היא להסיר ניקוד.
/// [removeNikudFromTanach] - האם להסיר ניקוד גם מספרי תנ"ך.
/// [isTanach] - האם הספר הנוכחי שייך לתנ"ך.
bool shouldRemoveNikudForBook({
  required bool defaultRemoveNikud,
  required bool removeNikudFromTanach,
  required bool isTanach,
}) {
  return defaultRemoveNikud && (removeNikudFromTanach || !isTanach);
}

/// מחזיר האם שינוי מצב ההגדרות מחייב טעינה מחדש של ספר פתוח.
bool shouldReloadForNikudSettingsChange({
  required SettingsState previous,
  required SettingsState current,
}) {
  return previous.defaultRemoveNikud != current.defaultRemoveNikud ||
      previous.removeNikudFromTanach != current.removeNikudFromTanach;
}

/// פותר האם להסיר ניקוד עבור ספר יעד, לפי הגדרות הניקוד והסיווג שלו.
Future<bool> resolveRemoveNikudForBook({
  required String title,
  required bool defaultRemoveNikud,
  required bool removeNikudFromTanach,
  int? categoryId,
  String? fileType,
}) async {
  if (!defaultRemoveNikud) {
    return false;
  }

  final isTanach = await FileSystemData.instance.isTanachBook(
    title,
    categoryId: categoryId,
    fileType: fileType,
  );

  return shouldRemoveNikudForBook(
    defaultRemoveNikud: defaultRemoveNikud,
    removeNikudFromTanach: removeNikudFromTanach,
    isTanach: isTanach,
  );
}
