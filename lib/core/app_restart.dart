import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

bool canRestartApplication() =>
  Platform.isWindows || Platform.isLinux || Platform.isMacOS;

String restartTargetDisplayName() =>
  Platform.isAndroid || Platform.isIOS ? 'האפליקציה' : 'התוכנה';

/// מפעיל מחדש את התוכנה אם הפלטפורמה תומכת בכך.
///
/// בדסקטופ נפתח מופע חדש של קובץ ההפעלה הנוכחי ואז נסגור את המופע הנוכחי.
/// במובייל אין דרך אמינה לפתוח מחדש את התוכנה, ולכן תתבצע סגירה רגילה בלבד.
Future<void> restartApplication() async {
  if (canRestartApplication()) {
    final executablePath = Platform.resolvedExecutable;
    final workingDirectory = p.dirname(executablePath);

    await Process.start(
      executablePath,
      const [],
      mode: ProcessStartMode.detached,
      workingDirectory: workingDirectory,
    );

    await windowManager.close();
    return;
  }

  if (Platform.isAndroid || Platform.isIOS) {
    await SystemNavigator.pop();
    return;
  }

  exit(0);
}