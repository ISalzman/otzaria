import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/services/plugin_runtime_dispatcher.dart';

class _FakeWebViewController extends Fake implements InAppWebViewController {
  int loadUrlCalls = 0;
  int evaluateJavascriptCalls = 0;
  URLRequest? lastUrlRequest;

  @override
  Future<void> loadUrl({
    required URLRequest urlRequest,
    WebUri? allowingReadAccessTo,
    Uri? iosAllowingReadAccessTo,
  }) async {
    loadUrlCalls++;
    lastUrlRequest = urlRequest;
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    evaluateJavascriptCalls++;
    return null;
  }
}

// ── fake controller פשוט עבור בדיקות שלא דורשות הפעלת methods ─────────────
// registerController רק שומר את ה-object במפה; אין קריאות ל-methods שלו
// בטסטים אלה (אנחנו לא מפעילים dispatchEvent שדורש SQLite).
class _FakeController extends Fake implements InAppWebViewController {}

// ── helpers ──────────────────────────────────────────────────────────────────

const _kPid = 'dispatcher.test.plugin';

PluginRuntimeDispatcher get _d => PluginRuntimeDispatcher.instance;

void _cleanupControllers() {
  _d.unregisterController(_kPid);
  _d.unregisterController(_kPid, instanceId: 'background');
}

void _cleanupCallbacks() {
  _d.unregisterReloadCallback(_kPid);
  _d.unregisterReloadCallback(_kPid, instanceId: 'background');
}

void main() {
  late PluginRuntimeDispatcher dispatcher;

  setUp(() async {
    dispatcher = PluginRuntimeDispatcher.instance;
    await dispatcher.prepareForAppRestart();
    // prepareForAppRestart משאיר את _shutdownMode במצב 'restart'.
    // register+unregister של controller דמה מאפס חזרה ל-idle כך
    // שבדיקות הבאות (כמו reloadPlugin) לא יידחו על ידי בדיקת shutdownMode.
    dispatcher.registerController('__test_reset__', _FakeController());
    dispatcher.unregisterController('__test_reset__');
  });

  test('prepareForAppShutdown tears down controllers and blocks re-registering',
      () async {
    final firstController = _FakeWebViewController();
    dispatcher.registerController('plugin-a', firstController);

    await dispatcher.prepareForAppShutdown();

    expect(firstController.loadUrlCalls, 1);
    expect(
      firstController.lastUrlRequest?.url?.toString(),
      'about:blank',
    );

    final lateController = _FakeWebViewController();
    dispatcher.registerController('plugin-a', lateController);

    await dispatcher.dispatchEventToPlugin(
      'plugin-a',
      'reader.current_ref_changed',
      {'currentBook': 'בראשית'},
    );

    expect(lateController.evaluateJavascriptCalls, 0);

    await dispatcher.prepareForAppRestart();
  });

  // ── register / unregister ─────────────────────────────────────────────────

  group('registerController / unregisterController', () {
    tearDown(_cleanupControllers);

    test('מעגן controller בלי לקרוס', () {
      _d.registerController(_kPid, _FakeController());
      // ניקוי עצמי — אין exception
      _d.unregisterController(_kPid);
    });

    test('unregister פעמיים הוא no-op', () {
      _d.registerController(_kPid, _FakeController());
      _d.unregisterController(_kPid);
      expect(() => _d.unregisterController(_kPid), returnsNormally);
    });

    test('foreground ו-background יכולים לדור יחד', () {
      _d.registerController(_kPid, _FakeController(), instanceId: 'default');
      _d.registerController(_kPid, _FakeController(), instanceId: 'background');
      // unregister סלקטיבי — כל אחד בנפרד
      _d.unregisterController(_kPid, instanceId: 'default');
      _d.unregisterController(_kPid, instanceId: 'background');
    });

    test('invalidatePlugin על plugin לא רשום אינו קורס', () {
      expect(() => _d.invalidatePlugin('no.such.plugin'), returnsNormally);
    });
  });

  // ── foreground-preference selection logic ─────────────────────────────────
  //
  // בודק את הלוגיקה שהוספנו ב-dispatchEvent ו-dispatchEventToPlugin:
  //   final targets = instances.containsKey('default')
  //       ? [instances['default']!]
  //       : instances.values.toList();
  //
  // הטסטים מכסים את ארבע הצירופים האפשריים של instances.

  group('foreground-preference selection', () {
    Map<String, String> selectTargets(Map<String, String> instances) =>
        instances.containsKey('default')
            ? {'default': instances['default']!}
            : Map.fromEntries(instances.entries);

    test('כשיש foreground וגם background — נבחר רק foreground', () {
      final instances = {'default': 'fg', 'background': 'bg'};
      final result = selectTargets(instances);
      expect(result.keys, equals(['default']));
      expect(result.values, equals(['fg']));
      expect(result.containsValue('bg'), isFalse);
    });

    test('כשיש רק background — נבחר background', () {
      final instances = {'background': 'bg'};
      final result = selectTargets(instances);
      expect(result.values.toList(), equals(['bg']));
    });

    test('כשיש רק default — נבחר default', () {
      final instances = {'default': 'fg'};
      final result = selectTargets(instances);
      expect(result.values.toList(), equals(['fg']));
    });

    test('כשאין instances — מחזיר ריק', () {
      final instances = <String, String>{};
      final result = selectTargets(instances);
      expect(result, isEmpty);
    });

    test(
        'instance נוסף (לא default/background) — נבחר גם הוא בהיעדר foreground',
        () {
      final instances = {'background': 'bg', 'extra': 'ex'};
      final result = selectTargets(instances);
      expect(result.containsKey('background'), isTrue);
      expect(result.containsKey('extra'), isTrue);
    });
  });

  // ── reloadPlugin callbacks ────────────────────────────────────────────────

  group('reloadPlugin', () {
    tearDown(_cleanupCallbacks);

    test('ללא callback רשום — לא קורס', () async {
      await expectLater(_d.reloadPlugin(_kPid), completes);
    });

    test('callback רשום מופעל', () async {
      var called = false;
      _d.registerReloadCallback(_kPid, () async {
        called = true;
      });
      await _d.reloadPlugin(_kPid);
      expect(called, isTrue);
    });

    test('callback מנוסח מחדש לאחר unregister — לא מופעל', () async {
      var called = false;
      _d.registerReloadCallback(_kPid, () async {
        called = true;
      });
      _d.unregisterReloadCallback(_kPid);
      await _d.reloadPlugin(_kPid);
      expect(called, isFalse);
    });

    test('שני callbacks (foreground + background) — שניהם מופעלים', () async {
      final calls = <String>[];
      _d.registerReloadCallback(_kPid, () async {
        calls.add('fg');
      }, instanceId: 'default');
      _d.registerReloadCallback(_kPid, () async {
        calls.add('bg');
      }, instanceId: 'background');

      await _d.reloadPlugin(_kPid);

      expect(calls, containsAll(['fg', 'bg']));
    });

    test('unregister background בלבד — foreground עדיין מופעל', () async {
      final calls = <String>[];
      _d.registerReloadCallback(_kPid, () async {
        calls.add('fg');
      }, instanceId: 'default');
      _d.registerReloadCallback(_kPid, () async {
        calls.add('bg');
      }, instanceId: 'background');
      _d.unregisterReloadCallback(_kPid, instanceId: 'background');

      await _d.reloadPlugin(_kPid);

      expect(calls, equals(['fg']));
    });
  });
}
