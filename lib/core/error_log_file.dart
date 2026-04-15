import 'dart:io';

import 'package:path/path.dart' as p;

enum ErrorLogPlatform {
  windows,
  macos,
  linux,
  android,
  ios,
  other,
}

class ErrorLogFile {
  static const String fileName = 'errors.txt';

  /// מחזירה את הנתיב המלא לקובץ השגיאות של האפליקציה.
  ///
  /// ברירת המחדל היא תיקייה כתיבה פר-משתמש, כדי להימנע
  /// מכתיבה לתיקיית ההתקנה שעלולה להיות חסומה להרשאות כתיבה.
  static String resolvePath({
    Map<String, String>? environment,
    ErrorLogPlatform? platform,
    String? tempPath,
  }) {
    final env = environment ?? Platform.environment;
    final currentPlatform = platform ?? _detectPlatform();
    final baseDir = _resolveBaseDirectory(
          environment: env,
          platform: currentPlatform,
        ) ??
        tempPath ??
        Directory.systemTemp.path;

    return p.join(baseDir, 'otzaria', 'logs', fileName);
  }

  /// מוסיפה רשומת שגיאה לקובץ הלוג המקומי.
  static void append(
    Object error, {
    StackTrace? stackTrace,
    DateTime? timestamp,
    Map<String, String>? environment,
    ErrorLogPlatform? platform,
    String? tempPath,
  }) {
    final file = File(resolvePath(
      environment: environment,
      platform: platform,
      tempPath: tempPath,
    ));

    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    file.writeAsStringSync(
      formatEntry(
        error,
        stackTrace: stackTrace,
        timestamp: timestamp,
      ),
      mode: FileMode.append,
      flush: true,
    );
  }

  /// בונה את תוכן הרשומה שתישמר בקובץ הלוג.
  static String formatEntry(
    Object error, {
    StackTrace? stackTrace,
    DateTime? timestamp,
  }) {
    final logBuffer = StringBuffer()
      ..writeln(
          '=== ${timestamp?.toIso8601String() ?? DateTime.now().toIso8601String()} ===')
      ..writeln(error);

    if (stackTrace != null) {
      logBuffer
        ..writeln()
        ..writeln(stackTrace);
    }

    logBuffer.writeln();
    return logBuffer.toString();
  }

  static String? _resolveBaseDirectory({
    required Map<String, String> environment,
    required ErrorLogPlatform platform,
  }) {
    switch (platform) {
      case ErrorLogPlatform.windows:
        return _firstNonEmpty([
          environment['LOCALAPPDATA'],
          environment['APPDATA'],
        ]);
      case ErrorLogPlatform.macos:
        final home = environment['HOME'];
        if (home == null || home.isEmpty) {
          return null;
        }
        return p.join(home, 'Library', 'Application Support');
      case ErrorLogPlatform.linux:
        return _firstNonEmpty([
          environment['XDG_STATE_HOME'],
          _joinIfHasValue(environment['HOME'], '.local', 'state'),
          _joinIfHasValue(environment['HOME'], '.local', 'share'),
        ]);
      case ErrorLogPlatform.android:
      case ErrorLogPlatform.ios:
      case ErrorLogPlatform.other:
        return _joinIfHasValue(environment['HOME'], '.otzaria');
    }
  }

  static ErrorLogPlatform _detectPlatform() {
    if (Platform.isWindows) {
      return ErrorLogPlatform.windows;
    }
    if (Platform.isMacOS) {
      return ErrorLogPlatform.macos;
    }
    if (Platform.isLinux) {
      return ErrorLogPlatform.linux;
    }
    if (Platform.isAndroid) {
      return ErrorLogPlatform.android;
    }
    if (Platform.isIOS) {
      return ErrorLogPlatform.ios;
    }
    return ErrorLogPlatform.other;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _joinIfHasValue(String? base, String part1, [String? part2]) {
    if (base == null || base.isEmpty) {
      return null;
    }
    if (part2 == null) {
      return p.join(base, part1);
    }
    return p.join(base, part1, part2);
  }
}
