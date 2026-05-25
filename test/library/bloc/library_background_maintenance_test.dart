import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/bloc/library_bloc.dart';

void main() {
  group('launchBackgroundLibraryMaintenance', () {
    test('מריץ את משימת התחזוקה ברקע בלי להמתין לסיומה', () async {
      final completer = Completer<void>();
      var started = false;
      var finished = false;

      completer.future.then((_) {
        finished = true;
      });

      launchBackgroundLibraryMaintenance(() {
        started = true;
        return completer.future;
      });

      expect(started, isTrue);

      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);

      completer.complete();
      await completer.future;
      expect(finished, isTrue);
    });

    test('מעביר שגיאה ל-handler במקום להפיל את הזרם הראשי', () async {
      Object? capturedError;

      launchBackgroundLibraryMaintenance(
        () => Future<void>.error(StateError('boom')),
        onError: (error) {
          capturedError = error;
        },
      );

      await Future<void>.delayed(Duration.zero);

      expect(capturedError, isA<StateError>());
      expect((capturedError as StateError).message, 'boom');
    });
  });
}
