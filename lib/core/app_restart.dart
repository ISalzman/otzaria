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
    final currentPid = pid;

    await _launchRestartProcessAfterExit(
      executablePath: executablePath,
      workingDirectory: workingDirectory,
      parentPid: currentPid,
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

Future<void> _launchRestartProcessAfterExit({
  required String executablePath,
  required String workingDirectory,
  required int parentPid,
}) async {
  if (Platform.isWindows) {
    final restartScript = File(
      p.join(Directory.systemTemp.path, 'otzaria_restart_$parentPid.vbs'),
    );

    final launchCommand = '"${_quoteVbScriptString(executablePath)}"';

    await restartScript.writeAsString(
      [
        'Set shell = CreateObject("WScript.Shell")',
        'Set wmi = GetObject("winmgmts:\\\\.\\root\\cimv2")',
        'Do While wmi.ExecQuery("Select * from Win32_Process Where ProcessId = $parentPid").Count > 0',
        '  WScript.Sleep 200',
        'Loop',
        'shell.CurrentDirectory = "${_quoteVbScriptString(workingDirectory)}"',
        'shell.Run "${_quoteVbScriptString(launchCommand)}", 0, False',
        'CreateObject("Scripting.FileSystemObject").DeleteFile WScript.ScriptFullName, True',
      ].join('\r\n'),
    );

    await Process.start(
      'wscript.exe',
      [restartScript.path],
      mode: ProcessStartMode.detached,
      workingDirectory: workingDirectory,
    );
    return;
  }

  if (Platform.isLinux || Platform.isMacOS) {
    final shellCommand = [
      'while kill -0 $parentPid 2>/dev/null; do sleep 0.2; done',
      'exec ${_quotePosixShell(executablePath)}',
    ].join('; ');

    await Process.start(
      '/bin/sh',
      ['-c', shellCommand],
      mode: ProcessStartMode.detached,
      workingDirectory: workingDirectory,
    );
    return;
  }

  await Process.start(
    executablePath,
    const [],
    mode: ProcessStartMode.detached,
    workingDirectory: workingDirectory,
  );
}

String _quoteVbScriptString(String value) => value.replaceAll('"', '""');

String _quotePosixShell(String value) =>
    "'${value.replaceAll("'", "'\"'\"'")}'";