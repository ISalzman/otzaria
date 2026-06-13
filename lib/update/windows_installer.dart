import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// האם האפליקציה מותקנת בנתיב מערכתי (Program Files) שדורש הרשאות מנהל
/// לשדרוג. per-user (LocalAppData\Programs) אינו דורש.
bool _isAdminInstall() {
  final exe = Platform.resolvedExecutable.toLowerCase();
  return exe.contains('\\program files\\') ||
      exe.contains('\\program files (x86)\\');
}

/// ארגומנטים למתקין בהתקנת per-user: /VERYSILENT ישירות (ללא הסלמה), כדי
/// לדלג על ה-self-relaunch של המתקין. /NOLAUNCH=1 מונע פתיחה מחדש של אוצריא
/// (בעת סגירת התוכנה).
@visibleForTesting
String perUserSilentInstallerArguments({required bool relaunchApp}) {
  const base = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER';
  return relaunchApp ? base : '$base /NOLAUNCH=1';
}

/// משגר את המתקין כך שהעדכון יותקן בפועל וישרוד את סגירת אוצריא.
///
/// אוצריא רצה בתוך Job Object (ראה windows/runner/flutter_window.cpp); תהליך
/// רגיל שמשוגר ע"י האפליקציה נהרג כשה-Job נסגר עם יציאתה, ולכן המתקין לא
/// מספיק לרוץ. לכן הוא נוצר ב-CreateProcess עם CREATE_BREAKAWAY_FROM_JOB
/// (ה-Job מתיר זאת) — מנותק מה-Job ושורד.
///
/// per-user מקבל /VERYSILENT ישירות. admin מושגר **ללא** /VERYSILENT —
/// המתקין (שכבר מנותק מה-Job) מסליק את עצמו ב-runas מתוך InitializeSetup,
/// ותהליך ה-runas שלו שורד כי האב כבר מחוץ ל-Job. מחזיר true אם היצירה הצליחה.
bool launchWindowsSilentInstaller({
  required String installerPath,
  required bool relaunchApp,
}) {
  final commandLine = _isAdminInstall()
      ? (relaunchApp ? '"$installerPath"' : '"$installerPath" /NOLAUNCH=1')
      : '"$installerPath" '
          '${perUserSilentInstallerArguments(relaunchApp: relaunchApp)}';
  return _createBreakawayProcess(commandLine);
}

/// יוצר תהליך מנותק מה-Job של אוצריא כך שישרוד את סגירתה. אם ה-Job אינו מתיר
/// breakaway — נסיגה ליצירה רגילה כדי לא להישבר לגמרי.
bool _createBreakawayProcess(String commandLine) {
  final cmdLinePtr = commandLine.toNativeUtf16();
  final si = calloc<STARTUPINFO>();
  si.ref.cb = sizeOf<STARTUPINFO>();
  final pi = calloc<PROCESS_INFORMATION>();
  try {
    const base = DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP;
    var ok = CreateProcess(nullptr, cmdLinePtr, nullptr, nullptr, FALSE,
        base | CREATE_BREAKAWAY_FROM_JOB, nullptr, nullptr, si, pi);
    if (ok == 0) {
      ok = CreateProcess(nullptr, cmdLinePtr, nullptr, nullptr, FALSE, base,
          nullptr, nullptr, si, pi);
    }
    if (ok == 0) return false;
    CloseHandle(pi.ref.hProcess);
    CloseHandle(pi.ref.hThread);
    return true;
  } finally {
    malloc.free(cmdLinePtr);
    calloc.free(si);
    calloc.free(pi);
  }
}
