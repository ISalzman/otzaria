import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/core/windowing/shared_hive_store.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
import 'package:otzaria/core/windowing/window_role.dart';

/// ⚠️ קידומת ייחודית לסוויטה. [ui.IsolateNameServer] גלובלי לתהליך —
/// בדיוק הסיבה שהאפיק עובד — ושתי סוויטות שרצות תחת אותו `flutter test`
/// תפסו את אותן המשבצות והפילו זו את זו. בהרצה קרה 4 מתוך 6 נכשלו.
const String _namespace = 'otzaria.test.sharedhive';

/// חלון "בעלים" מדומה.
///
/// ⚠️ הוא מריץ את **הקוד האמיתי** של צד הבעלים
/// ([SharedHiveStore.handleRequest]) ולא מימוש חלופי. הבדיקה הקודמת החליפה
/// את הצד הזה, ולכן הקוד שמשרת כל חלון משני לא נבדק כלל.
class _FakeOwner {
  _FakeOwner(this.slot);

  final int slot;
  final SharedHiveStore store = SharedHiveStore.owner();
  int readCount = 0;
  int writeCount = 0;
  late final ReceivePort _port;

  String get _name => '$_namespace.$slot';

  void register({bool asOwnerAlias = true}) {
    _port = ReceivePort();
    ui.IsolateNameServer.registerPortWithName(_port.sendPort, _name);
    if (asOwnerAlias) {
      ui.IsolateNameServer.registerPortWithName(
        _port.sendPort,
        '$_namespace.owner',
      );
    }
    _port.listen((message) async {
      final map = message as Map;
      final reply = map['reply'] as SendPort;
      final body = Map<String, dynamic>.from(map['body'] as Map);
      if (body['type'] == SharedHiveStore.requestRead) readCount++;
      if (body['type'] == SharedHiveStore.requestWrite) writeCount++;
      try {
        reply.send({'ok': true, 'result': await store.handleRequest(body)});
      } catch (e) {
        reply.send({'ok': false, 'error': '$e'});
      }
    });
  }

  void dispose() {
    ui.IsolateNameServer.removePortNameMapping(_name);
    ui.IsolateNameServer.removePortNameMapping('$_namespace.owner');
    _port.close();
  }
}

void main() {
  setUp(() {
    WindowBus.namespace = _namespace;
    Hive.init('${Directory.systemTemp.path}/otzaria_shared_hive_test');
  });

  tearDown(() async {
    WindowRole.isSecondary = false;
    WindowBus.instance.onRequest = null;
    WindowBus.instance.unregister();
    // ⚠️ המונים חייבים להתאפס. בלעדיו בדיקה מגיעה עם גרסאות מהבדיקה
    // הקודמת, וכתיבה מוגנת נדחית מסיבה שאין לה קשר למה שנבדק.
    SharedHiveStore.instance.resetForTest();
    for (var i = 1; i <= WindowBus.slotCount; i++) {
      ui.IsolateNameServer.removePortNameMapping('$_namespace.$i');
    }
    ui.IsolateNameServer.removePortNameMapping('$_namespace.owner');
    WindowBus.namespace = 'otzaria.window';
    await Hive.deleteFromDisk();
  });

  group('חלון ראשון (בעלים)', () {
    test('קורא וכותב ישירות למאגר המקומי, בלי אפיק', () async {
      await Hive.openBox<dynamic>('history');

      await SharedHiveStore.instance.write('history', 'history', [
        {'title': 'בראשית'},
      ]);
      final read = await SharedHiveStore.instance.read('history', 'history');

      expect(read.authoritative, isTrue);
      expect(read.asList, hasLength(1));
      expect((read.asList.first as Map)['title'], 'בראשית');
    });

    test('הגרסה מתקדמת בכל כתיבה', () async {
      await Hive.openBox<dynamic>('history');
      final before = await SharedHiveStore.instance.read('history', 'history');
      await SharedHiveStore.instance.write('history', 'history', const []);
      final after = await SharedHiveStore.instance.read('history', 'history');
      expect(after.revision, before.revision + 1);
    });

    test('כתיבה על גרסה מיושנת נדחית', () async {
      await Hive.openBox<dynamic>('history');
      final stale = await SharedHiveStore.instance.read('history', 'history');
      // חלון אחר כתב בינתיים.
      await SharedHiveStore.instance.write('history', 'history', [
        {'title': 'של האחר'},
      ]);

      await expectLater(
        SharedHiveStore.instance.write(
          'history',
          'history',
          const [],
          ifRevision: stale.revision,
        ),
        throwsA(isA<SharedHiveConflict>()),
      );
      // ⚠️ זו הנקודה: הרשומה של האחר **נשארה**.
      final now = await SharedHiveStore.instance.read('history', 'history');
      expect((now.asList.single as Map)['title'], 'של האחר');
    });

    test('כשל כתיבה מתפשט ואינו נבלע', () async {
      // ⚠️ ה-box אינו נפתח בכוונה. בליעת הכשל כאן הפכה שלוש שכבות לקוד
      // מת: ההודעה למשתמש, הניסיון החוזר, ודיווח הכשל ל-Sentry.
      await expectLater(
        SharedHiveStore.instance.write('history', 'history', const []),
        throwsA(anything),
      );
    });
  });

  group('חלון משני', () {
    test('קורא מהבעלים ולא מהמאגר המקומי', () async {
      final owner = _FakeOwner(1)..register();
      addTearDown(owner.dispose);
      await Hive.openBox<dynamic>('history');
      await owner.store.write('history', 'history', [
        {'title': 'שמות'},
      ]);

      WindowRole.isSecondary = true;
      WindowBus.instance.register();

      final read = await SharedHiveStore.instance.read('history', 'history');
      expect(read.authoritative, isTrue);
      expect((read.asList.single as Map)['title'], 'שמות');
      expect(owner.readCount, 1);
    });

    test('כתיבה מגיעה לבעלים', () async {
      final owner = _FakeOwner(1)..register();
      addTearDown(owner.dispose);
      await Hive.openBox<dynamic>('bookmarks');

      WindowRole.isSecondary = true;
      WindowBus.instance.register();

      await SharedHiveStore.instance.write('bookmarks', 'key-bookmarks', [
        {'title': 'סימנייה'},
      ]);

      expect(owner.writeCount, 1);
      final stored =
          Hive.box<dynamic>('bookmarks').get('key-bookmarks') as List<dynamic>;
      expect((stored.single as Map)['title'], 'סימנייה');
    });

    test('בלי בעלים — הקריאה מוצהרת כלא-מוסמכת ואינה "ריקה"', () async {
      WindowRole.isSecondary = true;
      WindowBus.instance.register();
      await Hive.openBox<dynamic>('history');

      final read = await SharedHiveStore.instance.read('history', 'history');

      // ⚠️ זו הנקודה. בעבר הוחזרה רשימה ריקה, ה-bloc קיבע אותה, והכתיבה
      // הראשונה שלו מחקה 200 רשומות אצל הבעלים.
      expect(read.authoritative, isFalse);
    });

    test('בלי בעלים — כתיבה נכשלת במקום לכתוב על עיוור', () async {
      WindowRole.isSecondary = true;
      WindowBus.instance.register();

      await expectLater(
        SharedHiveStore.instance.write('history', 'history', const []),
        throwsA(isA<SharedHiveUnavailable>()),
      );
    });

    test('התנגשות גרסאות מהבעלים מגיעה לקורא כ-SharedHiveConflict', () async {
      final owner = _FakeOwner(1)..register();
      addTearDown(owner.dispose);
      await Hive.openBox<dynamic>('history');

      WindowRole.isSecondary = true;
      WindowBus.instance.register();

      final stale = await SharedHiveStore.instance.read('history', 'history');
      await owner.store.write('history', 'history', [
        {'title': 'של הבעלים'},
      ]);

      await expectLater(
        SharedHiveStore.instance.write(
          'history',
          'history',
          const [],
          ifRevision: stale.revision,
        ),
        throwsA(isA<SharedHiveConflict>()),
      );
    });

    test('box שאינו ברשימת המשותפים נשאר מקומי', () async {
      final owner = _FakeOwner(1)..register();
      addTearDown(owner.dispose);
      await Hive.openBox<dynamic>('app_preferences');

      WindowRole.isSecondary = true;
      WindowBus.instance.register();

      await SharedHiveStore.instance.write('app_preferences', 'k', const [1]);

      expect(owner.writeCount, 0);
    });
  });

  test('isShared מכסה בדיוק את המאגרים שמנותבים', () {
    expect(SharedHiveStore.isShared('history'), isTrue);
    expect(SharedHiveStore.isShared('bookmarks'), isTrue);
    expect(SharedHiveStore.isShared('workspaces'), isTrue);
    // הכרטיסיות מנותבות כדי שיישמרו בכלל — כל חלון תחת מפתח משלו.
    expect(SharedHiveStore.isShared('tabs'), isTrue);
    // ⚠️ אין box בשם 'notes'. הוא הופיע ברשימה והצהיר על שיתוף שלא היה.
    expect(SharedHiveStore.isShared('notes'), isFalse);
    expect(SharedHiveStore.isShared('app_preferences'), isFalse);
  });

  test('מפתח הכרטיסיות ייחודי לכל חלון, והראשון שומר על המפתח ההיסטורי', () {
    expect(SharedHiveStore.tabsKeyForWindow(null, 'key-tabs'), 'key-tabs');
    expect(
      SharedHiveStore.tabsKeyForWindow(2, 'key-tabs'),
      'key-tabs-window-2',
    );
    expect(
      SharedHiveStore.tabsKeyForWindow(3, 'key-tabs'),
      'key-tabs-window-3',
    );
  });
}
