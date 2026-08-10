import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_lazy_activation_service.dart';

void main() {
  late PluginLazyActivationService service;
  late List<String> activations;
  late List<(String pluginId, String topic, Map<String, dynamic> payload)>
  delivered;

  setUp(() {
    service = PluginLazyActivationService.forTesting()
      ..startupDelayOverride = Duration.zero;
    activations = [];
    delivered = [];
    service.backgroundActivator = (pluginId) async {
      activations.add(pluginId);
    };
    service.deliverOverride = (pluginId, topic, payload) async {
      delivered.add((pluginId, topic, payload));
    };
  });

  test('targeted event on a non-activatable plugin is rejected', () {
    expect(service.queueTargetedEvent('p1', 'click', {}), isFalse);
    expect(activations, isEmpty);
  });

  test('targeted events queue, activate once, and flush in order', () async {
    service.syncPlugin(
      'p1',
      broadcastTopics: const {},
      scheduleStartup: false,
    );

    expect(service.queueTargetedEvent('p1', 'click', {'n': 1}), isTrue);
    expect(service.queueTargetedEvent('p1', 'click', {'n': 2}), isTrue);
    expect(activations, ['p1']);
    expect(delivered, isEmpty);

    await service.onBackgroundInstanceReady('p1');
    expect(delivered.map((e) => e.$3['n']), [1, 2]);

    // ריקון חוזר — התור כבר ריק.
    await service.onBackgroundInstanceReady('p1');
    expect(delivered, hasLength(2));
  });

  test('broadcast wakes only declared topics without a usable instance', () {
    service.syncPlugin(
      'declared',
      broadcastTopics: const {'reader.sectionContentChanged'},
      scheduleStartup: false,
    );
    service.syncPlugin(
      'other-topic',
      broadcastTopics: const {'theme.changed'},
      scheduleStartup: false,
    );
    service.syncPlugin(
      'alive',
      broadcastTopics: const {'reader.sectionContentChanged'},
      scheduleStartup: false,
    );

    service.onBroadcast(
      'reader.sectionContentChanged',
      {},
      hasUsableInstance: (pluginId) => pluginId == 'alive',
    );

    expect(activations, ['declared']);
  });

  test('app.startup fires once per session, even after re-sync', () async {
    service.syncPlugin(
      'p1',
      broadcastTopics: const {},
      scheduleStartup: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(activations, ['p1']);

    await service.onBackgroundInstanceReady('p1');
    service.syncPlugin(
      'p1',
      broadcastTopics: const {},
      scheduleStartup: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(activations, ['p1']);
  });

  test('removed plugin is not activated by a scheduled app.startup', () async {
    service.syncPlugin(
      'p1',
      broadcastTopics: const {},
      scheduleStartup: true,
    );
    service.removePlugin('p1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(activations, isEmpty);
  });

  test(
    'revocation invalidates an activation already waiting on init',
    () async {
      final initGate = Completer<void>();
      var attachedAfterInit = false;
      service.backgroundActivator = (pluginId) async {
        final generation = service.activationGeneration(pluginId);
        await initGate.future;
        attachedAfterInit = service.trackIdleTeardown(
          pluginId,
          generation: generation,
        );
      };
      service.syncPlugin(
        'p1',
        broadcastTopics: const {},
        scheduleStartup: false,
      );

      service.queueTargetedEvent('p1', 'click', {});
      service.removePlugin('p1');
      initGate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(attachedAfterInit, isFalse);
      expect(service.isBootPending('p1'), isFalse);
    },
  );

  group('idle teardown', () {
    late List<String> deactivations;

    setUp(() {
      deactivations = [];
      service.idleDelayOverride = const Duration(milliseconds: 30);
      service.backgroundDeactivator = deactivations.add;
      service.syncPlugin(
        'p1',
        broadcastTopics: const {},
        scheduleStartup: false,
      );
    });

    test('an idle tracked instance is torn down after the delay', () async {
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(deactivations, ['p1']);
    });

    test('activity resets the idle timer', () async {
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');

      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        service.notifyActivity('p1');
      }
      expect(deactivations, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(deactivations, ['p1']);
    });

    test('keepAlive prevents idle teardown until it is revoked', () async {
      service.syncPlugin(
        'p1',
        broadcastTopics: const {},
        scheduleStartup: false,
        keepAlive: true,
      );
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(deactivations, isEmpty);

      service.syncPlugin(
        'p1',
        broadcastTopics: const {},
        scheduleStartup: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(deactivations, ['p1']);
    });

    test('backgroundDone still tears down a keepAlive instance', () async {
      service.syncPlugin(
        'p1',
        broadcastTopics: const {},
        scheduleStartup: false,
        keepAlive: true,
      );
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');

      expect(service.requestImmediateTeardown('p1'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(deactivations, ['p1']);
    });

    test('an untracked (eager) instance is never torn down', () async {
      await service.onBackgroundInstanceReady('p1');

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(deactivations, isEmpty);
    });

    test('closing the instance cancels the timer', () async {
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');
      service.onBackgroundInstanceClosed('p1');

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(deactivations, isEmpty);
    });

    test('removePlugin tears down a tracked running instance', () async {
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');

      service.removePlugin('p1');

      expect(deactivations, ['p1']);
    });

    test('removePlugin does not deactivate an untracked plugin', () {
      service.removePlugin('p1');
      expect(deactivations, isEmpty);
    });

    test('a busy instance (RPC in flight) is not torn down', () async {
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');

      service.beginWork('p1');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(deactivations, isEmpty, reason: 'RPC ארוך באמצע — אסור לקטוע');

      service.endWork('p1');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(deactivations, ['p1']);
    });

    test('nested RPCs keep the instance busy until the last ends', () async {
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');

      service.beginWork('p1');
      service.beginWork('p1');
      service.endWork('p1');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(deactivations, isEmpty);

      service.endWork('p1');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(deactivations, ['p1']);
    });

    test(
      'backgroundDone tears down immediately, without the idle wait',
      () async {
        // שעון ארוך בכוונה — הכיבוי חייב להגיע מהבקשה המפורשת, לא מהשעון.
        service.idleDelayOverride = const Duration(seconds: 30);
        service.trackIdleTeardown('p1');
        await service.onBackgroundInstanceReady('p1');

        expect(service.requestImmediateTeardown('p1'), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(deactivations, ['p1']);
      },
    );

    test('backgroundDone on an untracked instance is a safe no-op', () async {
      expect(service.requestImmediateTeardown('p1'), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(deactivations, isEmpty);
    });

    test('backgroundDone defers when new work started meanwhile', () async {
      service.idleDelayOverride = const Duration(milliseconds: 50);
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');

      expect(service.requestImmediateTeardown('p1'), isTrue);
      service.beginWork('p1');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(deactivations, isEmpty, reason: 'RPC חדש נפתח — לא קוטעים');

      service.endWork('p1');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(deactivations, ['p1'], reason: 'ומשם — השעון הרגיל');
    });

    test('a torn-down plugin can be re-activated by the next click', () async {
      service.trackIdleTeardown('p1');
      await service.onBackgroundInstanceReady('p1');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(deactivations, ['p1']);
      service.onBackgroundInstanceClosed('p1');

      expect(service.queueTargetedEvent('p1', 'click', {}), isTrue);
      expect(activations, contains('p1'));
    });
  });

  test('queueIfBootPending queues only while a boot is in flight', () async {
    service.syncPlugin(
      'p1',
      broadcastTopics: const {},
      scheduleStartup: false,
    );

    expect(service.queueIfBootPending('p1', 'click', {'n': 0}), isFalse);

    service.queueTargetedEvent('p1', 'click', {'n': 1});
    expect(service.isBootPending('p1'), isTrue);
    expect(service.queueIfBootPending('p1', 'click', {'n': 2}), isTrue);

    await service.onBackgroundInstanceReady('p1');
    expect(delivered.map((e) => e.$3['n']), [1, 2]);
    expect(service.isBootPending('p1'), isFalse);
  });

  test('failed activation drops the pending queue and allows retry', () async {
    service.backgroundActivator = (pluginId) async {
      activations.add(pluginId);
      throw StateError('no runtime');
    };
    service.syncPlugin(
      'p1',
      broadcastTopics: const {},
      scheduleStartup: false,
    );

    service.queueTargetedEvent('p1', 'click', {'n': 1});
    await Future<void>.delayed(Duration.zero);
    await service.onBackgroundInstanceReady('p1');
    expect(delivered, isEmpty);

    // הפעלה חוזרת אפשרית אחרי הכשל.
    service.queueTargetedEvent('p1', 'click', {'n': 2});
    expect(activations, hasLength(2));
  });

  test('failed background boot clears pending state and allows retry', () {
    service.syncPlugin(
      'p1',
      broadcastTopics: const {},
      scheduleStartup: false,
    );

    service.queueTargetedEvent('p1', 'click', {'n': 1});
    expect(service.isBootPending('p1'), isTrue);

    service.onBackgroundInstanceFailed('p1');
    expect(service.isBootPending('p1'), isFalse);

    service.queueTargetedEvent('p1', 'click', {'n': 2});
    expect(activations, ['p1', 'p1']);
  });

  test('late close from a failed generation does not cancel its retry', () {
    service.syncPlugin(
      'p1',
      broadcastTopics: const {},
      scheduleStartup: false,
    );
    final failedGeneration = service.activationGeneration('p1');
    service.queueTargetedEvent('p1', 'click', {'n': 1});

    service.onBackgroundInstanceFailed(
      'p1',
      generation: failedGeneration,
    );
    expect(service.activationGeneration('p1'), failedGeneration + 1);
    service.queueTargetedEvent('p1', 'click', {'n': 2});
    expect(service.isBootPending('p1'), isTrue);

    service.onBackgroundInstanceClosed(
      'p1',
      generation: failedGeneration,
    );

    expect(service.isBootPending('p1'), isTrue);
    expect(activations, ['p1', 'p1']);
  });
}
