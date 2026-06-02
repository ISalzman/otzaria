import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_adapter.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_handler.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';

/// adapter פיקטיבי: מיישם רק את execute (השאר דרך noSuchMethod), סופר קריאות
/// ומחזיר ערך מוגדר מראש — כך אפשר לוודא אם execute נקרא בכלל ובאילו ארגומנטים.
class _FakeAdapter implements PluginBridgeAdapter {
  _FakeAdapter({this.result});

  final dynamic result;
  int executeCalls = 0;
  String? lastDomain;
  String? lastAction;

  @override
  Future<dynamic> execute(
      String domain, String action, Map<String, dynamic> args) async {
    executeCalls++;
    lastDomain = domain;
    lastAction = action;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// registry שמחזיר ערך הרשאה קבוע ל-getPermission, בלי גישה ל-DB.
class _StubRegistry extends PluginRegistryRepository {
  _StubRegistry(this.grantValue);

  /// הערך שיוחזר מ-getPermission: true=הוענקה, false=נדחתה, null=לא הוגדרה.
  final bool? grantValue;

  @override
  Future<bool?> getPermission(String pluginId, String permission) async {
    return grantValue;
  }
}

/// RateLimiter שתמיד חוסם וסופר כמה פעמים נקרא — לבדיקת צימוד throttle/הרשאה
/// בלי תלות בתזמון (consume אמיתי מתחדש לפי שעון).
class _BlockingRateLimiter extends RateLimiter {
  int consumeCalls = 0;

  @override
  bool consume() {
    consumeCalls++;
    return false;
  }
}

InstalledPlugin _buildInstalledPlugin({List<String> permissions = const []}) {
  return InstalledPlugin(
    pluginId: 'test.plugin',
    name: 'Test Plugin',
    version: '1.0.0',
    installPath: '/',
    entrypointPath: 'index.html',
    enabled: true,
    pinned: true,
    manifest: PluginManifest(
      schemaVersion: 1,
      id: 'test.plugin',
      name: 'Test Plugin',
      version: '1.0.0',
      description: '',
      author: '',
      homepage: '',
      entrypoint: 'index.html',
      minAppVersion: '1.0.0',
      sdkVersion: '1.x',
      permissions: permissions,
      networkEnabled: false,
      networkAllowlist: const [],
      toolTabTitle: 'Test Plugin',
      toolTabOrder: 1,
      defaultPinned: true,
      publishedDataTypes: const [],
    ),
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

/// בקשת RPC ל-getBookContent (הקריאה היחידה המוחרגת ממגביל הקצב).
List<dynamic> _getBookContentRequest() => [
      {
        'method': 'library.getBookContent',
        'payload': {'bookId': 'ספר-כלשהו'},
      }
    ];

void main() {
  group('PluginBridgeHandler.isRateLimitExempt', () {
    test('library.getBookContent מוחרג ממגביל הקצב', () {
      // טעינת ספר מלא מחולקת ל-chunks ומחייבת עשרות קריאות רצופות; ספירתן
      // במגביל הקצב חתכה את הטעינה באמצע (חצי ספר).
      expect(PluginBridgeHandler.isRateLimitExempt('library.getBookContent'),
          isTrue);
    });

    test('קריאות אחרות אינן מוחרגות וממשיכות להיות מוגבלות', () {
      expect(
          PluginBridgeHandler.isRateLimitExempt('library.getBookToc'), isFalse);
      expect(PluginBridgeHandler.isRateLimitExempt('library.getTree'), isFalse);
      expect(PluginBridgeHandler.isRateLimitExempt('storage.set'), isFalse);
      expect(PluginBridgeHandler.isRateLimitExempt('reader.setHighlight'),
          isFalse);
      expect(PluginBridgeHandler.isRateLimitExempt(''), isFalse);
    });
  });

  group('RateLimiter', () {
    test('מתחיל עם 50 טוקנים וחוסם לאחר שהם נגמרים בפרץ אחד', () {
      final limiter = RateLimiter();
      var allowed = 0;
      // פרץ מיידי של 60 קריאות: 50 הראשונות אמורות לעבור, השאר להיחסם
      // (הטוקנים מתחדשים רק ~1 כל 10ms, וכאן אין שהייה ביניהן).
      for (var i = 0; i < 60; i++) {
        if (limiter.consume()) allowed++;
      }
      expect(allowed, lessThanOrEqualTo(51));
      expect(allowed, greaterThanOrEqualTo(50));
    });
  });

  // אכיפת ההרשאות ב-_handleRpc עצמו — לא רק שה-helper הסטטי מחזיר true.
  // getBookContent דורש את ההרשאה 'library.content.read', וההחרגה ממגביל הקצב
  // מותנית בכך שההרשאה *הוענקה בפועל* (ראה ההערה ב-plugin_bridge_handler.dart).
  group('PluginBridgeHandler._handleRpc — אכיפת הרשאות', () {
    const contentPermission = 'library.content.read';

    PluginBridgeHandler buildHandler({
      required List<String> declaredPermissions,
      required bool? granted,
      required _FakeAdapter adapter,
      RateLimiter? rateLimiter,
    }) {
      return PluginBridgeHandler(
        _buildInstalledPlugin(permissions: declaredPermissions),
        adapter: adapter,
        registry: _StubRegistry(granted),
        rateLimiter: rateLimiter,
      );
    }

    test(
        'הרשאה הוצהרה אך לא הוענקה → permission_denied, adapter.execute לא נקרא',
        () async {
      final adapter = _FakeAdapter();
      final handler = buildHandler(
        declaredPermissions: const [contentPermission],
        granted: false,
        adapter: adapter,
      );

      final resp = await handler.handleRpcForTesting(_getBookContentRequest())
          as Map<String, dynamic>;

      expect(resp['success'], isFalse);
      expect(resp['error']['code'], 'permission_denied');
      expect(adapter.executeCalls, 0);
    });

    test('הרשאה לא הוצהרה כלל במניפסט → permission_denied, execute לא נקרא',
        () async {
      final adapter = _FakeAdapter();
      final handler = buildHandler(
        declaredPermissions: const [], // המניפסט ריק
        granted: true, // גם אם ה-DB היה מאשר — ההצהרה חסרה
        adapter: adapter,
      );

      final resp = await handler.handleRpcForTesting(_getBookContentRequest())
          as Map<String, dynamic>;

      expect(resp['success'], isFalse);
      expect(resp['error']['code'], 'permission_denied');
      expect(adapter.executeCalls, 0);
    });

    test('הרשאה הוצהרה והוענקה → הצלחה, adapter.execute נקרא', () async {
      final adapter = _FakeAdapter(result: 'תוכן-הספר');
      final handler = buildHandler(
        declaredPermissions: const [contentPermission],
        granted: true,
        adapter: adapter,
      );

      final resp = await handler.handleRpcForTesting(_getBookContentRequest())
          as Map<String, dynamic>;

      expect(resp['success'], isTrue);
      expect(resp['data'], 'תוכן-הספר');
      expect(adapter.executeCalls, 1);
      expect(adapter.lastDomain, 'library');
      expect(adapter.lastAction, 'getBookContent');
    });

    test(
        'ההחרגה ממגביל הקצב חלה רק כשההרשאה הוענקה: מגביל מרוקן + הרשאה מוענקת '
        '→ עדיין מצליח (consume לא נקרא)', () async {
      // grantedEarly=true ⇒ exempt=true ⇒ הקוד לא קורא ל-consume כלל.
      final adapter = _FakeAdapter(result: 'תוכן');
      final limiter = _BlockingRateLimiter();
      final handler = buildHandler(
        declaredPermissions: const [contentPermission],
        granted: true,
        adapter: adapter,
        rateLimiter: limiter,
      );

      final resp = await handler.handleRpcForTesting(_getBookContentRequest())
          as Map<String, dynamic>;

      expect(resp['success'], isTrue,
          reason: 'getBookContent עם הרשאה מוענקת מוחרג ממגביל הקצב');
      expect(limiter.consumeCalls, 0,
          reason: 'נתיב מוחרג לא אמור לגעת במגביל הקצב בכלל');
    });

    test(
        'תוסף ללא הרשאה מוענקת אינו עוקף את ה-throttle: מגביל מרוקן + הרשאה לא '
        'מוענקת → rate_limited (עובר דרך המגביל)', () async {
      // grantedEarly=false ⇒ exempt=false ⇒ הקריאה עוברת דרך consume, שמרוקן
      // ולכן חוסם. כך תוסף לא-מורשה לא מנצל את ההחרגה כדי לעקוף את ה-throttle.
      final adapter = _FakeAdapter();
      final limiter = _BlockingRateLimiter();
      final handler = buildHandler(
        declaredPermissions: const [contentPermission],
        granted: false,
        adapter: adapter,
        rateLimiter: limiter,
      );

      final resp = await handler.handleRpcForTesting(_getBookContentRequest())
          as Map<String, dynamic>;

      expect(resp['success'], isFalse);
      expect(resp['error']['code'], 'error.rate_limited');
      expect(limiter.consumeCalls, 1,
          reason: 'תוסף לא-מורשה חייב לעבור דרך מגביל הקצב, לא לעקוף אותו');
      expect(adapter.executeCalls, 0);
    });
  });
}
