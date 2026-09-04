// ⚠️ Windows בלבד, ובמכוון.
//
// כל מסלול הגרירה מגודר ב-`MultiWindowService.isSupported`, שהוא
// `Platform.isWindows` — הצד הנייטיב מומש ב-`windows/runner`. על Linux
// (שם רצות שש ה-shards של ה-CI) `windowAtCursor` ו-`openWindow` חוזרים
// מיד בלי לגעת בערוץ, ולכן ה-runner המדומה כאן לא היה נקרא כלל וההצהרות
// היו נכשלות מסיבה שאין לה קשר למה שנבדק.
//
// גידור הקובץ ולא הצהרות בודדות: בדיקה שמדלגת על החלק המעניין שלה
// ונשארת ירוקה גרועה מבדיקה שאינה רצה.
@TestOn('windows')
library;

import 'dart:isolate';
import 'dart:ui' as ui show IsolateNameServer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/windowing/cross_window_tab_drag.dart';
import 'package:otzaria/core/windowing/multi_window_service.dart';
import 'package:otzaria/core/windowing/window_bus.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/tool_tab.dart';

/// ⚠️ קידומת ייחודית לסוויטה — [ui.IsolateNameServer] גלובלי לתהליך.
const String _namespace = 'otzaria.test.crosswindowdrag';

/// מסלול הגרירה בין חלונות נבדק עד כה **ידנית בלבד**, וזה הפער שהדוח סימן.
/// כאן נבדקת ההחלטה עצמה: מה קורה לכרטיסיה בכל אחת מארבע התוצאות.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRunner runner;
  late _RecordingTabsBloc tabsBloc;
  late CrossWindowTabDrag drag;

  setUp(() {
    WindowBus.namespace = _namespace;
    runner = _FakeRunner()..install();
    tabsBloc = _RecordingTabsBloc(
      TabsState(
        tabs: [
          ToolTab(toolId: 'builtin.calendar', title: 'לוח שנה'),
          ToolTab(toolId: 'builtin.gematria', title: 'גימטריה'),
        ],
        currentTabIndex: 0,
      ),
    );
    drag = CrossWindowTabDrag();
  });

  tearDown(() async {
    drag.dispose();
    runner.uninstall();
    await tabsBloc.close();
    WindowBus.instance.unregister();
    for (var i = 1; i <= WindowBus.slotCount; i++) {
      ui.IsolateNameServer.removePortNameMapping('$_namespace.$i');
    }
    WindowBus.namespace = 'otzaria.window';
  });

  OpenedTab firstTab() => tabsBloc.state.tabs.first;

  test('שחרור מעל החלון עצמו אינו עושה דבר', () async {
    // ⚠️ שחרור בתוך החלון שלא פגע ביעד הפלה. בלי התנאי הזה כל גרירה
    // שהתפספסה הייתה פותחת חלון.
    runner.cursorTarget = (slot: 1, isSelf: true, isShellTray: false);

    await drag.handleDroppedOutside(firstTab(), tabsBloc);

    expect(tabsBloc.events, isEmpty);
    expect(runner.openWindowCalls, 0);
  });

  test('שחרור מעל שורת המשימות מבוטל ואינו פותח חלון', () async {
    // ⚠️ שורת המשימות נגישה גם בחלון ממוקסם, ולכן שחרור עליה הוא כמעט
    // תמיד החטאה. קודם לכן הוא פתח חלון שני והכרטיסיה עזבה — שינוי
    // בהתנהגות שמשתמש בחלון יחיד נתקל בו בטעות.
    runner.cursorTarget = (slot: null, isSelf: false, isShellTray: true);

    await drag.handleDroppedOutside(firstTab(), tabsBloc);

    expect(tabsBloc.events, isEmpty);
    expect(runner.openWindowCalls, 0);
  });

  test('שחרור מעל שולחן העבודה פותח חלון והכרטיסיה עוברת', () async {
    runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);

    await drag.handleDroppedOutside(firstTab(), tabsBloc);

    expect(runner.openWindowCalls, 1);
    expect(tabsBloc.events.whereType<RemoveTab>(), hasLength(1));
  });

  test('כשל פתיחה משאיר את הכרטיסיה במקומה', () async {
    // ⚠️ זו כל הנקודה בכך ש-`openWindow` ממתין ליצירה בפועל: מחיקה על סמך
    // "הצלחה" שלא נבדקה הייתה מאבדת את הכרטיסיה.
    runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
    runner.openWindowResult = false;

    await drag.handleDroppedOutside(firstTab(), tabsBloc);

    expect(tabsBloc.events.whereType<RemoveTab>(), isEmpty);
  });

  test('הכרטיסיה האחרונה אינה יוצאת לחלון חדש', () async {
    // גרירתה החוצה הייתה משאירה חלון ריק ופותחת חדש — תזוזה בלי תועלת.
    tabsBloc.emitState(
      TabsState(tabs: [firstTab()], currentTabIndex: 0),
    );
    runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);

    await drag.handleDroppedOutside(firstTab(), tabsBloc);

    expect(runner.openWindowCalls, 0);
    expect(tabsBloc.events, isEmpty);
  });

  test('שחרור מעל חלון אחר שולח אליו, והכרטיסיה מוסרת רק אחרי אישור', () async {
    final peer = _FakePeer(2, accept: true)..register();
    addTearDown(peer.dispose);
    runner.cursorTarget = (slot: 2, isSelf: false, isShellTray: false);

    await drag.handleDroppedOutside(firstTab(), tabsBloc);

    expect(peer.receivedTabs, 1);
    expect(runner.openWindowCalls, 0);
    expect(tabsBloc.events.whereType<RemoveTab>(), hasLength(1));
  });

  test('חלון יעד שלא אישר — הכרטיסיה נשארת ואינה נעלמת משני הצדדים', () async {
    final peer = _FakePeer(2, accept: false)..register();
    addTearDown(peer.dispose);
    runner.cursorTarget = (slot: 2, isSelf: false, isShellTray: false);

    await drag.handleDroppedOutside(firstTab(), tabsBloc);

    expect(peer.receivedTabs, 1);
    expect(tabsBloc.events.whereType<RemoveTab>(), isEmpty);
  });

  test('כרטיסיה שאינה שורדת סריאליזציה נחסמת לפני כל ניסיון העברה', () async {
    runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
    tabsBloc.emitState(
      TabsState(
        tabs: [_UnserializableTab(), firstTab()],
        currentTabIndex: 0,
      ),
    );

    await drag.handleDroppedOutside(tabsBloc.state.tabs.first, tabsBloc);

    expect(runner.openWindowCalls, 0);
    expect(tabsBloc.events, isEmpty);
  });
}

/// ה-runner המדומה — עונה על ערוץ `otzaria/multiwindow`.
class _FakeRunner {
  ({int? slot, bool isSelf, bool isShellTray}) cursorTarget = (
    slot: null,
    isSelf: false,
    isShellTray: false,
  );
  bool openWindowResult = true;
  int openWindowCalls = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MultiWindowService.channel, (call) async {
          switch (call.method) {
            case 'windowAtCursor':
              return {
                'slot': cursorTarget.slot,
                'isSelf': cursorTarget.isSelf,
                'isShellTray': cursorTarget.isShellTray,
                'x': 100,
                'y': 200,
              };
            case 'openWindow':
              openWindowCalls++;
              return openWindowResult;
            case 'windowCount':
              return {'count': 1, 'max': 4};
            default:
              return null;
          }
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MultiWindowService.channel, null);
  }
}

/// חלון יעד מדומה על האפיק.
class _FakePeer {
  _FakePeer(this.slot, {required this.accept});

  final int slot;
  final bool accept;
  int receivedTabs = 0;
  late final ReceivePort _port;

  void register() {
    _port = ReceivePort();
    ui.IsolateNameServer.registerPortWithName(
      _port.sendPort,
      '$_namespace.$slot',
    );
    _port.listen((message) {
      final map = message as Map;
      final reply = map['reply'] as SendPort;
      final body = Map<String, dynamic>.from(map['body'] as Map);
      if (body['type'] == MultiWindowService.requestReceiveTab) {
        receivedTabs++;
        reply.send({'ok': true, 'result': accept});
        return;
      }
      reply.send({'ok': true, 'result': null});
    });
  }

  void dispose() {
    ui.IsolateNameServer.removePortNameMapping('$_namespace.$slot');
    _port.close();
  }
}

class _RecordingTabsBloc extends Cubit<TabsState> implements TabsBloc {
  _RecordingTabsBloc(super.initialState);

  final List<TabsEvent> events = [];

  void emitState(TabsState state) => emit(state);

  @override
  void add(TabsEvent event) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnserializableTab extends OpenedTab {
  _UnserializableTab() : super('כרטיסיה שבורה');

  @override
  Map<String, dynamic> toJson() => {'type': 'DefinitelyNotATabType'};

  @override
  OpenedTab clone() => _UnserializableTab();
}
