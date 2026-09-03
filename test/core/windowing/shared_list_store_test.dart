import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/core/windowing/shared_list_store.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
import 'package:otzaria/core/windowing/window_role.dart';

/// חלון "בעלים" מדומה שעונה על בקשות קריאה וכתיבה.
class _FakeOwner {
  _FakeOwner(this.slot);

  final int slot;
  final Map<String, List<dynamic>> data = {};
  int writeCount = 0;
  late final ReceivePort _port;

  void register() {
    _port = ReceivePort();
    ui.IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'otzaria.window.$slot',
    );
    _port.listen((message) {
      final map = message as Map;
      final reply = map['reply'] as SendPort;
      final body = Map<String, dynamic>.from(map['body'] as Map);
      reply.send({'ok': true, 'result': _handle(body)});
    });
  }

  Object? _handle(Map<String, dynamic> body) {
    switch (body['type']) {
      case 'describe':
        return {'title': 'בעלים', 'tabCount': 1, 'isOwner': true};
      case SharedListStore.requestRead:
        return data['${body['box']}/${body['key']}'] ?? <dynamic>[];
      case SharedListStore.requestWrite:
        writeCount++;
        data['${body['box']}/${body['key']}'] =
            (body['value'] as List).toList();
        return true;
    }
    return null;
  }

  void dispose() {
    ui.IsolateNameServer.removePortNameMapping('otzaria.window.$slot');
    _port.close();
  }
}

void main() {
  setUp(() {
    Hive.init('${Directory.systemTemp.path}/otzaria_shared_store_test');
  });

  tearDown(() async {
    WindowRole.isSecondary = false;
    WindowBus.instance.onRequest = null;
    WindowBus.instance.unregister();
    for (var i = 1; i <= WindowBus.slotCount; i++) {
      ui.IsolateNameServer.removePortNameMapping('otzaria.window.$i');
    }
    await Hive.deleteFromDisk();
  });

  group('חלון ראשון (בעלים)', () {
    test('קורא וכותב ישירות למאגר המקומי, בלי אפיק', () async {
      WindowRole.isSecondary = false;
      await Hive.openBox<dynamic>('history');

      await SharedListStore.instance.write('history', 'history', [
        {'title': 'בראשית'},
      ]);
      final read = await SharedListStore.instance.read('history', 'history');

      expect(read, hasLength(1));
      expect((read.first as Map)['title'], 'בראשית');
    });
  });

  group('חלון משני', () {
    test('קורא מהבעלים ולא מהמאגר המקומי', () async {
      final owner = _FakeOwner(1)..register();
      addTearDown(owner.dispose);
      owner.data['history/history'] = [
        {'title': 'שמות'},
      ];

      WindowRole.isSecondary = true;
      WindowBus.instance.register(); // תופס 2
      await Hive.openBox<dynamic>('history');
      // המאגר המקומי מכיל משהו אחר לגמרי — כדי שיהיה ברור מאיפה הגיע הערך.
      await Hive.box<dynamic>('history').put('history', [
        {'title': 'מקומי'},
      ]);

      final read = await SharedListStore.instance.read('history', 'history');
      expect((read.single as Map)['title'], 'שמות');
    });

    test('כותב גם לבעלים וגם מקומית', () async {
      final owner = _FakeOwner(1)..register();
      addTearDown(owner.dispose);

      WindowRole.isSecondary = true;
      WindowBus.instance.register();
      await Hive.openBox<dynamic>('bookmarks');

      await SharedListStore.instance.write('bookmarks', 'bookmarks', [
        {'title': 'סימנייה'},
      ]);

      expect(owner.writeCount, 1);
      // ⚠️ הכתיבה המקומית אינה כפילות מיותרת: היא העותק שיישאר אם החלון
      // הראשון ייסגר, ובלעדיה סגירתו הייתה מאבדת את מה שנכתב כאן.
      final local =
          Hive.box<dynamic>('bookmarks').get('bookmarks') as List<dynamic>;
      expect((local.single as Map)['title'], 'סימנייה');
    });

    test('בלי בעלים — נופל למאגר המקומי ולא מחזיר ריק', () async {
      WindowRole.isSecondary = true;
      WindowBus.instance.register();
      await Hive.openBox<dynamic>('history');
      await Hive.box<dynamic>('history').put('history', [
        {'title': 'נשמר קודם'},
      ]);

      // אין אף חלון אחר רשום — הבעלים "נסגר".
      final read = await SharedListStore.instance.read('history', 'history');

      // ⚠️ זו הנקודה: מסך ריק נראה למשתמש כמו אובדן נתונים, ולכן עדיף
      // תוכן לא-מסונכרן על תוכן ריק.
      expect((read.single as Map)['title'], 'נשמר קודם');
    });

    test('box שאינו ברשימת המשותפים נשאר מקומי גם בחלון משני', () async {
      final owner = _FakeOwner(1)..register();
      addTearDown(owner.dispose);

      WindowRole.isSecondary = true;
      WindowBus.instance.register();
      await Hive.openBox<dynamic>('tabs');

      await SharedListStore.instance.write('tabs', 'tabs', [
        {'type': 'ToolTab'},
      ]);

      // ⚠️ הכרטיסיות הפתוחות הן מצב פר-חלון. ניתובן לבעלים היה גורם לכל
      // החלונות להציג את אותן כרטיסיות.
      expect(owner.writeCount, 0);
      expect(
        Hive.box<dynamic>('tabs').get('tabs'),
        isA<List<dynamic>>().having((l) => l.length, 'length', 1),
      );
    });
  });

  test('כשל כתיבה בחלון הראשון מתפשט ואינו נבלע', () async {
    WindowRole.isSecondary = false;
    // ⚠️ ה-box אינו נפתח בכוונה. בליעת הכשל כאן הפכה שלוש שכבות לקוד
    // מת: ההודעה למשתמש, הניסיון החוזר, ודיווח הכשל ל-Sentry.
    await expectLater(
      SharedListStore.instance.write('history', 'history', const []),
      throwsA(anything),
    );
  });

  test('isShared מכסה בדיוק את ארבעת המאגרים שהמשתמש מצפה שישותפו', () {
    expect(SharedListStore.isShared('history'), isTrue);
    expect(SharedListStore.isShared('bookmarks'), isTrue);
    expect(SharedListStore.isShared('workspaces'), isTrue);
    expect(SharedListStore.isShared('notes'), isTrue);
    expect(SharedListStore.isShared('tabs'), isFalse);
    expect(SharedListStore.isShared('app_preferences'), isFalse);
  });
}
