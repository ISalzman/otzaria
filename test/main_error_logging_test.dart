import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/error_log_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formatEntry כותב Version לפני Exception', () {
    ErrorLogFile.setAppVersion('9.8.7+65');

    final output = ErrorLogFile.formatEntry(
      title: 'FlutterError',
      error: StateError('boom'),
      stackTrace: StackTrace.fromString('stack-line-1\nstack-line-2'),
      details: const {
        'Library': 'widgets library',
        'Context': 'while building test widget',
      },
    );

    expect(output, contains('FlutterError'));
    expect(output, contains('Version: 9.8.7+65'));
    expect(output, contains('Bad state: boom'));
    expect(output, contains('widgets library'));
    expect(output, contains('while building test widget'));
    expect(output, contains('stack-line-1'));
  });

  test('formatEntry מטפל בפרטים מרובי שורות', () {
    final output = ErrorLogFile.formatEntry(
      title: 'Initialization Warning',
      error: ArgumentError('bad input'),
      stackTrace: StackTrace.fromString('platform-stack'),
      details: const {
        'Information': 'line 1\nline 2',
      },
    );

    expect(output, contains('Initialization Warning'));
    expect(output, contains('Invalid argument(s): bad input'));
    expect(output, contains('Information:'));
    expect(output, contains('line 1'));
    expect(output, contains('line 2'));
    expect(output, contains('platform-stack'));
  });
}
