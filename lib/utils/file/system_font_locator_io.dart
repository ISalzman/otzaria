import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

List<String> _fontDirectories() {
  if (Platform.isWindows) {
    return [
      '${Platform.environment['windir']}\\Fonts',
      '${Platform.environment['USERPROFILE']}\\AppData\\Local\\Microsoft\\Windows\\Fonts',
    ];
  }
  if (Platform.isMacOS) {
    return [
      '/Library/Fonts',
      '/System/Library/Fonts',
      '${Platform.environment['HOME']}/Library/Fonts',
    ];
  }
  if (Platform.isLinux) {
    return [
      '/usr/share/fonts',
      '/usr/local/share/fonts',
      '${Platform.environment['HOME']}/.local/share/fonts',
    ];
  }
  return const [];
}

bool _isFontFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.ttf') || lower.endsWith('.otf');
}

List<String> installedFontPaths() {
  final seen = <String>{};
  final result = <String>[];
  void add(String path) {
    if (!_isFontFile(path)) return;
    if (seen.add(path.toLowerCase())) result.add(path);
  }

  for (final dir in _fontDirectories()) {
    try {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is File) add(entity.path);
      }
    } catch (_) {
      // תיקייה חסרה או ללא הרשאת קריאה — ממשיכים לשאר המקורות.
    }
  }

  if (Platform.isWindows) {
    try {
      _registryFontPaths().forEach(add);
    } catch (_) {
      // כשל בקריאת ה-registry אינו מונע את גופני התיקיות.
    }
  }

  return result;
}

const _fontsSubKey = r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';

/// הגופנים כפי שווינדוס רושם אותם; ערך ללא נתיב = קובץ בתיקיית המערכת.
List<String> _registryFontPaths() {
  final windowsFontsDir =
      '${Platform.environment['windir'] ?? r'C:\Windows'}\\Fonts';
  final result = <String>[];
  for (final hive in [LOCAL_MACHINE, CURRENT_USER]) {
    final RegistryKey key;
    try {
      key = hive.open(_fontsSubKey);
    } catch (_) {
      continue;
    }
    try {
      for (final entry in key.values) {
        final value = entry.value;
        if (value is! StringValue) continue;
        final path = value.value.trim();
        if (path.isEmpty) continue;
        result.add(path.contains('\\') ? path : '$windowsFontsDir\\$path');
      }
    } finally {
      key.close();
    }
  }
  return result;
}
