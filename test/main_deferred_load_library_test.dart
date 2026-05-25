import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/main.dart';

void main() {
  group('scheduleAfterTwoFrames', () {
    test('מתזמן פעולה רק אחרי שני post-frame callbacks', () {
      final scheduledCallbacks = <FrameCallback>[];
      var callCount = 0;

      scheduleAfterTwoFrames(
        () {
          callCount++;
        },
        scheduleFrameCallback: scheduledCallbacks.add,
      );

      expect(callCount, 0);
      expect(scheduledCallbacks, hasLength(1));

      final firstCallback = scheduledCallbacks.removeLast();
      firstCallback(Duration.zero);

      expect(callCount, 0);
      expect(scheduledCallbacks, hasLength(1));

      final secondCallback = scheduledCallbacks.removeLast();
      secondCallback(Duration.zero);

      expect(callCount, 1);
      expect(scheduledCallbacks, isEmpty);
    });
  });
}
