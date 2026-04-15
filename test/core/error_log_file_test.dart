import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/error_log_file.dart';
import 'package:path/path.dart' as p;

void main() {
  test('resolvePath uses LocalAppData on Windows', () {
    final path = ErrorLogFile.resolvePath(
      platform: ErrorLogPlatform.windows,
      environment: {
        'LOCALAPPDATA': r'C:\Users\tester\AppData\Local',
      },
      tempPath: r'C:\Temp',
    );

    expect(
      path,
      p.join(r'C:\Users\tester\AppData\Local', 'otzaria', 'logs', 'errors.txt'),
    );
  });

  test('resolvePath falls back to temp when no writable home is available', () {
    final path = ErrorLogFile.resolvePath(
      platform: ErrorLogPlatform.other,
      environment: const {},
      tempPath: r'C:\Temp',
    );

    expect(path, p.join(r'C:\Temp', 'otzaria', 'logs', 'errors.txt'));
  });

  test('formatEntry includes timestamp and stack trace when provided', () {
    final entry = ErrorLogFile.formatEntry(
      'boom',
      stackTrace: StackTrace.fromString('stack-line'),
      timestamp: DateTime.utc(2026, 4, 15, 12, 0, 0),
    );

    expect(entry, contains('2026-04-15T12:00:00.000Z'));
    expect(entry, contains('boom'));
    expect(entry, contains('stack-line'));
  });
}
