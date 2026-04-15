import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formatFlutterErrorDetailsForLog מחזיר טקסט קריא עם exception ו-stack',
      () {
    final details = FlutterErrorDetails(
      exception: StateError('boom'),
      stack: StackTrace.fromString('stack-line-1\nstack-line-2'),
      library: 'widgets library',
      context: ErrorDescription('while building test widget'),
    );

    final output = formatFlutterErrorDetailsForLog(details);

    expect(output, contains('FlutterError'));
    expect(output, contains('Bad state: boom'));
    expect(output, contains('widgets library'));
    expect(output, contains('while building test widget'));
    expect(output, contains('stack-line-1'));
  });

  test('formatPlatformErrorForLog מחזיר טקסט קריא עם exception ו-stack', () {
    final output = formatPlatformErrorForLog(
      ArgumentError('bad input'),
      StackTrace.fromString('platform-stack'),
    );

    expect(output, contains('Unhandled Error'));
    expect(output, contains('Invalid argument(s): bad input'));
    expect(output, contains('platform-stack'));
  });
}
