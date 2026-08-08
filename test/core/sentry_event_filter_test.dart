import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/sentry_event_filter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('מזהה רעש AXTree של Flutter', () {
    expect(
      isFlutterAccessibilityNoise('Failed to update ui::AXTree, error: 3405'),
      isTrue,
    );
    expect(
      isFlutterAccessibilityNoise('accessibility_bridge.cc(114)'),
      isTrue,
    );
    expect(isFlutterAccessibilityNoise('StateError: test'), isFalse);
  });

  SentryEvent eventWithHandledState(bool handled) {
    return SentryEvent(
      exceptions: [
        SentryException(
          type: 'StateError',
          value: 'test',
          mechanism: Mechanism(type: 'test', handled: handled),
        ),
      ],
    );
  }

  test('שולח חריגה לא מטופלת מהגרסה האחרונה', () {
    expect(
      shouldReportSentryEvent(
        event: eventWithHandledState(false),
        currentBuild: 90950,
        latestReleasedBuildNumber: 90950,
      ),
      isTrue,
    );
  });

  test('מסנן חריגות שטופלו, הודעות וגרסאות ישנות', () {
    expect(
      shouldReportSentryEvent(
        event: eventWithHandledState(true),
        currentBuild: 90950,
        latestReleasedBuildNumber: 90950,
      ),
      isFalse,
    );
    expect(
      shouldReportSentryEvent(
        event: SentryEvent(message: SentryMessage('test')),
        currentBuild: 90950,
        latestReleasedBuildNumber: 90950,
      ),
      isFalse,
    );
    expect(
      shouldReportSentryEvent(
        event: eventWithHandledState(false),
        currentBuild: 90940,
        latestReleasedBuildNumber: 90950,
      ),
      isFalse,
    );
  });

  test('מסנן רעשי מערכת מוכרים גם כשהם לא טופלו', () {
    final event = SentryEvent(
      exceptions: [
        SentryException(
          type: 'StateError',
          value: 'Failed to update ui::AXTree',
          mechanism: Mechanism(type: 'test', handled: false),
        ),
      ],
    );

    expect(
      shouldReportSentryEvent(
        event: event,
        currentBuild: 90950,
        latestReleasedBuildNumber: 90950,
      ),
      isFalse,
    );
  });
}
