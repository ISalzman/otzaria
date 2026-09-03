import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui show IsolateNameServer;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/core/windowing/shared_hive_store.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
import 'package:otzaria/core/windowing/window_role.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';
import 'package:otzaria/tabs/tabs_repository.dart';

/// ⚠️ קידומת ייחודית לסוויטה — [ui.IsolateNameServer] גלובלי לתהליך.
const String _namespace = 'otzaria.test.windowsession';

/// חלון "בעלים" מדומה, שמריץ את הצד האמיתי של [SharedHiveStore].
class _FakeOwner {
  _FakeOwner();

  final SharedHiveStore store = SharedHiveStore.owner();
  late final ReceivePort _port;

  void register() {
    _port = ReceivePort();
    ui.IsolateNameServer.registerPortWithName(_port.sendPort, '$_namespace.1');
    ui.IsolateNameServer.registerPortWithName(
      _port.sendPort,
      '$_namespace.owner',
    );
    _port.listen((message) async {
      final map = message as Map;
      final reply = map['reply'] as SendPort;
      final body = Map<String, dynamic>.from(map['body'] as Map);
      try {
        reply.send({'ok': true, 'result': await store.handleRequest(body)});
      } catch (e) {
        reply.send({'ok': false, 'error': '$e'});
      }
    });
  }

  void dispose() {
    ui.IsolateNameServer.removePortNameMapping('$_namespace.1');
    ui.IsolateNameServer.removePortNameMapping('$_namespace.owner');
    _port.close();
  }
}

ToolTab _tab(String title) => ToolTab(toolId: 'builtin.calendar', title: title);

void main() {
  setUp(() async {
    WindowBus.namespace = _namespace;
    Hive.init('${Directory.systemTemp.path}/otzaria_window_session_test');
    await Hive.openBox<dynamic>(TabsRepository.boxName);
  });

  tearDown(() async {
    WindowRole.isSecondary = false;
    WindowBus.instance.unregister();
    SharedHiveStore.instance.resetForTest();
    for (var i = 1; i <= WindowBus.slotCount; i++) {
      ui.IsolateNameServer.removePortNameMapping('$_namespace.$i');
    }
    ui.IsolateNameServer.removePortNameMapping('$_namespace.owner');
    WindowBus.namespace = 'otzaria.window';
    await Hive.deleteFromDisk();
  });

  group('החלון הראשון', () {
    test('שומר וטוען את המפתח ההיסטורי', () async {
      final repo = TabsRepository();
      await repo.saveTabs([_tab('לוח שנה')], 0);

      expect(
        Hive.box<dynamic>(TabsRepository.boxName).get('key-tabs'),
        isA<List<dynamic>>().having((l) => l.length, 'length', 1),
      );
      expect(repo.loadTabs().single.title, 'לוח שנה');
    });
  });

  group('חלון משני', () {
    test('כותב תחת מפתח משלו, ולא על הסשן של החלון הראשון', () async {
      final owner = _FakeOwner()..register();
      addTearDown(owner.dispose);

      // הסשן של החלון הראשון, שאסור לו להיפגע.
      await TabsRepository().saveTabs([_tab('של הראשון')], 0);

      WindowRole.isSecondary = true;
      final slot = WindowBus.instance.register();
      await TabsRepository().saveTabs([_tab('של המשני')], 0);

      final box = Hive.box<dynamic>(TabsRepository.boxName);
      final own = box.get('key-tabs') as List<dynamic>;
      expect((own.single as Map)['title'], 'של הראשון');

      final mine = box.get('key-tabs-window-$slot') as List<dynamic>;
      expect((mine.single as Map)['title'], 'של המשני');
    });

    test('אינו משחזר כרטיסיות — חלון חדש אינו יורש שרידים', () async {
      final owner = _FakeOwner()..register();
      addTearDown(owner.dispose);

      WindowRole.isSecondary = true;
      final slot = WindowBus.instance.register();
      await TabsRepository().saveTabs([_tab('נשמר')], 0);
      // הסשן אכן על הדיסק...
      expect(
        Hive.box<dynamic>(TabsRepository.boxName).get('key-tabs-window-$slot'),
        isNotNull,
      );
      // ...אבל חלון משני נפתח עם הכרטיסיה שהועברה אליו, לא איתו.
      expect(TabsRepository().loadTabs(), isEmpty);
      expect(TabsRepository().loadCurrentTabIndex(), 0);
    });

    test('בלי משבצת אינו כותב כלל, ובשום מצב לא על key-tabs', () async {
      await TabsRepository().saveTabs([_tab('של הראשון')], 0);

      // ⚠️ אין רישום באפיק. נפילה למפתח ההיסטורי כאן הייתה דורסת את
      // הכרטיסיות של החלון הראשון.
      WindowRole.isSecondary = true;
      await TabsRepository().saveTabs([_tab('לא אמור להישמר')], 0);

      final own =
          Hive.box<dynamic>(TabsRepository.boxName).get('key-tabs') as List;
      expect((own.single as Map)['title'], 'של הראשון');
    });

    test('discardWindowSession מוחק את הסשן ואת האינדקס', () async {
      final owner = _FakeOwner()..register();
      addTearDown(owner.dispose);

      WindowRole.isSecondary = true;
      final slot = WindowBus.instance.register();
      final repo = TabsRepository();
      await repo.saveTabs([_tab('נסגר')], 0);
      await repo.discardWindowSession();

      final box = Hive.box<dynamic>(TabsRepository.boxName);
      expect(box.get('key-tabs-window-$slot'), isNull);
      expect(box.get('key-current-tab-window-$slot'), isNull);
    });
  });

  group('אימוץ סשנים יתומים', () {
    test('מצרף לחלון הראשון ומוחק את המפתחות', () async {
      final box = Hive.box<dynamic>(TabsRepository.boxName);
      await TabsRepository().saveTabs([_tab('של הראשון')], 0);
      // סשן שנשאר כי התהליך מת בלי סגירה מסודרת.
      await box.put('key-tabs-window-2', [_tab('יתום א').toJson()]);
      await box.put('key-current-tab-window-2', 0);
      await box.put('key-tabs-window-3', [_tab('יתום ב').toJson()]);

      final adopted = await TabsRepository.adoptOrphanWindowSessions();

      expect(adopted, 2);
      expect(TabsRepository().loadTabs().map((t) => t.title), [
        'של הראשון',
        'יתום א',
        'יתום ב',
      ]);
      expect(box.get('key-tabs-window-2'), isNull);
      expect(box.get('key-current-tab-window-2'), isNull);
      expect(box.get('key-tabs-window-3'), isNull);
    });

    test('אידמפוטנטי — הרצה שנייה אינה מכפילה', () async {
      final box = Hive.box<dynamic>(TabsRepository.boxName);
      await box.put('key-tabs-window-2', [_tab('יתום').toJson()]);

      expect(await TabsRepository.adoptOrphanWindowSessions(), 1);
      expect(await TabsRepository.adoptOrphanWindowSessions(), 0);
      expect(TabsRepository().loadTabs(), hasLength(1));
    });

    test('אינו רץ בחלון משני', () async {
      final box = Hive.box<dynamic>(TabsRepository.boxName);
      await box.put('key-tabs-window-2', [_tab('יתום').toJson()]);

      WindowRole.isSecondary = true;
      expect(await TabsRepository.adoptOrphanWindowSessions(), 0);
      expect(box.get('key-tabs-window-2'), isNotNull);
    });
  });
}
