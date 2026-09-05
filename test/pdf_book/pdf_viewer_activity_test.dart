import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/pdf_book/utils/pdf_viewer_activity.dart';

void main() {
  final activity = PdfViewerActivity.instance;

  tearDown(() {
    while (activity.loadingCount.value > 0) {
      activity.end();
    }
  });

  group('PdfViewerActivity', () {
    test('begin/end מאזנים את המונה', () {
      activity.begin();
      activity.begin();
      expect(activity.loadingCount.value, 2);
      activity.end();
      expect(activity.loadingCount.value, 1);
      activity.end();
      expect(activity.loadingCount.value, 0);
    });

    test('waitUntilIdle חוזר מיד כשאין viewer בטעינה', () {
      fakeAsync((async) {
        var done = false;
        activity.waitUntilIdle().then((_) => done = true);
        async.flushMicrotasks();
        expect(done, isTrue);
      });
    });

    test('waitUntilIdle ממתין עד שהמונה יורד לאפס', () {
      fakeAsync((async) {
        activity.begin();
        var done = false;
        activity.waitUntilIdle().then((_) => done = true);
        async.elapse(const Duration(seconds: 1));
        expect(done, isFalse);
        activity.end();
        async.flushMicrotasks();
        expect(done, isTrue);
      });
    });

    test('waitUntilIdle משתחרר ב-timeout בלי לזרוק', () {
      fakeAsync((async) {
        activity.begin();
        var done = false;
        activity
            .waitUntilIdle(timeout: const Duration(seconds: 2))
            .then((_) => done = true);
        async.elapse(const Duration(seconds: 1));
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(done, isTrue);
        expect(activity.loadingCount.value, 1);
        activity.end();
      });
    });
  });
}
