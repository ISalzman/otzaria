import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/indexing/services/indexing_wakelock.dart';

void main() {
  group('IndexingWakelock', () {
    late List<bool> calls;
    late ValueNotifier<bool> isIndexing;

    IndexingWakelock build({bool isMobile = true}) => IndexingWakelock(
      isMobile: isMobile,
      setEnabled: (enabled) async => calls.add(enabled),
    );

    setUp(() {
      calls = [];
      isIndexing = ValueNotifier(false);
    });

    tearDown(() => isIndexing.dispose());

    test('מדליק בתחילת אינדוקס ומכבה בסיומו', () {
      build().attach(isIndexing);
      expect(calls, isEmpty);

      isIndexing.value = true;
      expect(calls, [true]);

      isIndexing.value = false;
      expect(calls, [true, false]);
    });

    test('אינדוקס שכבר רץ ברגע ה-attach מדליק מיד', () {
      isIndexing.value = true;
      build().attach(isIndexing);
      expect(calls, [true]);
    });

    test('attach חוזר עם אותו listenable אינו מכפיל מאזינים', () {
      final wakelock = build();
      wakelock.attach(isIndexing);
      wakelock.attach(isIndexing);

      isIndexing.value = true;
      expect(calls, [true]);
    });

    test('בדסקטופ אינו נרשם ואינו נוגע ב-wakelock', () {
      build(isMobile: false).attach(isIndexing);
      isIndexing.value = true;
      expect(calls, isEmpty);
    });

    test('attach ל-listenable חדש מנתק את הקודם', () {
      final wakelock = build();
      wakelock.attach(isIndexing);

      final replacement = ValueNotifier(false);
      addTearDown(replacement.dispose);
      wakelock.attach(replacement);

      isIndexing.value = true;
      expect(calls, isEmpty);

      replacement.value = true;
      expect(calls, [true]);
    });
  });
}
