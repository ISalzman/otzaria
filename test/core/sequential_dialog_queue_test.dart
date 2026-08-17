import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/sequential_dialog_queue.dart';

void main() {
  group('SequentialDialogQueue', () {
    test('מציג פריט יחיד מיד', () async {
      final shown = <int>[];
      final queue = SequentialDialogQueue<int>((item) async {
        shown.add(item);
      });

      queue.enqueue(1);
      await Future<void>.delayed(Duration.zero);

      expect(shown, [1]);
    });

    test('פריט שני ממתין עד שהראשון נסגר — לא נערמים', () async {
      final shown = <int>[];
      final completers = <int, Completer<void>>{};
      final queue = SequentialDialogQueue<int>((item) {
        shown.add(item);
        final completer = Completer<void>();
        completers[item] = completer;
        return completer.future;
      });

      queue.enqueue(1);
      queue.enqueue(2);
      queue.enqueue(3);
      await Future<void>.delayed(Duration.zero);

      // רק הראשון מוצג כל עוד לא נסגר.
      expect(shown, [1]);

      completers[1]!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(shown, [1, 2]);

      completers[2]!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(shown, [1, 2, 3]);
    });

    test('פריט שנוסף בזמן הצגה מוצג אחרי הסגירה', () async {
      final shown = <int>[];
      final completer = Completer<void>();
      final queue = SequentialDialogQueue<int>((item) {
        shown.add(item);
        return item == 1 ? completer.future : Future.value();
      });

      queue.enqueue(1);
      await Future<void>.delayed(Duration.zero);
      queue.enqueue(2);
      await Future<void>.delayed(Duration.zero);
      expect(shown, [1]);

      completer.complete();
      await Future<void>.delayed(Duration.zero);
      expect(shown, [1, 2]);
    });

    test('clear מבטל פריטים ממתינים אך לא את המוצג כעת', () async {
      final shown = <int>[];
      final completer = Completer<void>();
      final queue = SequentialDialogQueue<int>((item) {
        shown.add(item);
        return completer.future;
      });

      queue.enqueue(1);
      queue.enqueue(2);
      await Future<void>.delayed(Duration.zero);
      queue.clear();

      completer.complete();
      await Future<void>.delayed(Duration.zero);
      expect(shown, [1]);
    });

    test('כשל בהצגה לא תוקע את התור — הבא מוצג', () async {
      final shown = <int>[];
      final queue = SequentialDialogQueue<int>((item) async {
        shown.add(item);
        if (item == 1) throw StateError('boom');
      });

      await runZonedGuarded(() async {
        queue.enqueue(1);
        queue.enqueue(2);
        await Future<void>.delayed(Duration.zero);
      }, (_, _) {});

      expect(shown, [1, 2]);
    });
  });
}
