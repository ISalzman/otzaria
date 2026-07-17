import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';

void main() {
  group('TantivyDataProvider.isRebuildRequiredStatus', () {
    test('מחזיר true כשהאינדקס ישן מדי עבור המנוע (rebuild_required)', () {
      expect(
        TantivyDataProvider.isRebuildRequiredStatus('rebuild_required'),
        isTrue,
      );
    });

    test('מחזיר true כשהאינדקס נוצר ע"י מנוע חדש יותר (engine_too_old)', () {
      expect(
        TantivyDataProvider.isRebuildRequiredStatus('engine_too_old'),
        isTrue,
      );
    });

    test('מחזיר false לאינדקס תקין', () {
      expect(
        TantivyDataProvider.isRebuildRequiredStatus('compatible'),
        isFalse,
      );
      expect(
        TantivyDataProvider.isRebuildRequiredStatus('legacy_compatible'),
        isFalse,
      );
    });

    test('מחזיר false כשאין אינדקס - אינדוקס רגיל יבנה אותו', () {
      expect(
        TantivyDataProvider.isRebuildRequiredStatus('missing_index'),
        isFalse,
      );
    });

    test('מחזיר false כשבדיקת התאימות לא רצה (null)', () {
      expect(TantivyDataProvider.isRebuildRequiredStatus(null), isFalse);
    });
  });

  group('ReopenGate', () {
    test('force בזמן reopen רץ — ממתין לו ואז פותח פתיחה חדשה משלו', () async {
      // רגרסיה: force שהסתפק ב-reopen שכבר רץ קיבל פתיחה שהתחילה לפני
      // הכשל — והיא עלולה הייתה לקרוא מהדיסק מצב ישן ולהשאיר מעקב מעופש.
      final gate = ReopenGate();
      final firstStarted = Completer<void>();
      final firstRelease = Completer<void>();
      final log = <String>[];

      final first = gate.run(() async {
        log.add('start-1');
        firstStarted.complete();
        await firstRelease.future;
        log.add('end-1');
      });
      await firstStarted.future;

      final forced = gate.run(() async {
        log.add('start-2');
      }, force: true);

      // הפתיחה הכפויה ממתינה — היא לא מתחילה לפני שהראשונה הסתיימה.
      await Future<void>.delayed(Duration.zero);
      expect(log, ['start-1']);

      firstRelease.complete();
      expect(await first, isTrue);
      expect(await forced, isTrue);
      expect(log, ['start-1', 'end-1', 'start-2']);
    });

    test('בלי force בזמן reopen רץ — ממתין ומחזיר true בלי פתיחה שנייה',
        () async {
      final gate = ReopenGate();
      final release = Completer<void>();
      var calls = 0;

      final first = gate.run(() async {
        calls++;
        await release.future;
      });
      final second = gate.run(() async {
        calls++;
      });

      release.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(calls, 1);
    });

    test('קריאה שנייה בתוך 5 שניות מדולגת (false) — אלא אם force', () async {
      final gate = ReopenGate();
      var calls = 0;

      expect(await gate.run(() async => calls++), isTrue);
      expect(await gate.run(() async => calls++), isFalse);
      expect(calls, 1);
      expect(await gate.run(() async => calls++, force: true), isTrue);
      expect(calls, 2);
    });

    test('force אחרי reopen רץ שנכשל — לא יורש את כשלו ופותח פתיחה חדשה',
        () async {
      final gate = ReopenGate();
      final release = Completer<void>();
      var forcedRan = false;

      final first = gate.run(() async {
        await release.future;
        throw StateError('reopen failed');
      });
      final forced = gate.run(() async {
        forcedRan = true;
      }, force: true);

      release.complete();
      await expectLater(first, throwsStateError);
      expect(await forced, isTrue);
      expect(forcedRan, isTrue);
    });

    test('reopen שנכשל בלי ממתין מקביל — לא מדליף unhandled async error',
        () async {
      // רגרסיה: העותק העטוף שנשמר ב-_inFlight ירש את השגיאה, וכשאיש לא
      // המתין לו היא דווחה כשגיאה אסינכרונית לא-מטופלת.
      final gate = ReopenGate();

      await expectLater(
        gate.run(() async => throw StateError('reopen failed')),
        throwsStateError,
      );
      // ניקוז תור המיקרוטסקים — שגיאה לא-מטופלת הייתה מפילה את הבדיקה.
      await Future<void>.delayed(Duration.zero);
    });
  });
}
