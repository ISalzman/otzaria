// ⚠️ רצה בכל פלטפורמה, ובמכוון.
//
// כל מסלול הגרירה מגודר ב-`MultiWindowService.isSupported`, שהוא
// `Platform.isWindows`, ולכן הקובץ היה מסומן `@TestOn('windows')` — וה-CI
// רץ על ubuntu. כלומר כל הבדיקות כאן היו ירוקות על מכונת המפתח בלבד.
// ההיגיון שנבדק אינו תלוי פלטפורמה: מה שמעבר לערוץ מדומה ב-[_FakeRunner],
// ו-`debugSupportedOverride` פותח את השער.
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/windowing/cross_window_tab_drag.dart';
import 'package:otzaria/core/windowing/drag_preview_colors.dart';
import 'package:otzaria/core/windowing/multi_window_service.dart';
import 'package:otzaria/core/windowing/tab_drag_preview.dart';
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
    MultiWindowService.debugSupportedOverride = true;
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
    MultiWindowService.debugSupportedOverride = null;
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

  test('החלון נפתח בנקודת השחרור ולא בהיסט מהפינה', () async {
    // ⚠️ עד כה החלון נפתח בהיסט מדורג מהפינה, בלי קשר למקום שאליו גררו —
    // גררת לפינה התחתונה-ימנית והחלון קפץ למעלה-שמאלה. רשימת ה-QA של
    // הענף כן דרשה "חלון חדש במיקום הסמן".
    runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);

    await drag.handleDroppedOutside(firstTab(), tabsBloc);

    expect(runner.lastOpenArgs?['originX'], 100);
    expect(runner.lastOpenArgs?['originY'], 200);
  });

  group('הרוח שהוקפאה במקום השחרור', () {
    test('סיום גרירה מקפיא ואינו מסתיר', () async {
      // ⚠️ `onDragFinishedAnywhere` נורה **לפני** השחרור, ולכן בשלב הזה
      // עוד לא ידוע אם ייפתח חלון. הסתרה מיידית השאירה את המסך ריק בדיוק
      // בפרק הזמן שבו המשתמש מחכה לראות תוצאה.
      drag.end();
      await Future<void>.delayed(Duration.zero);

      expect(runner.freezeCalls, 1);
      expect(runner.endCalls, 0);
    });

    test('פתיחת חלון משאירה אותה — היא תוחלף בחלון האמיתי', () async {
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);

      await drag.handleDroppedOutside(firstTab(), tabsBloc);

      expect(runner.endCalls, 0);
    });

    test('שחרור לחלון קיים מסתיר מיד — אין מה להחליף', () async {
      final peer = _FakePeer(2, accept: true)..register();
      addTearDown(peer.dispose);
      runner.cursorTarget = (slot: 2, isSelf: false, isShellTray: false);

      await drag.handleDroppedOutside(firstTab(), tabsBloc);

      expect(runner.endCalls, 1);
    });

    test('כל מסלול שאינו פותח חלון מסתיר', () async {
      // ⚠️ ההפך היה משאיר רוח מרחפת על המסך אחרי גרירה שהתבטלה.
      runner.cursorTarget = (slot: 1, isSelf: true, isShellTray: false);
      await drag.handleDroppedOutside(firstTab(), tabsBloc);
      expect(runner.endCalls, 1);

      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: true);
      await drag.handleDroppedOutside(firstTab(), tabsBloc);
      expect(runner.endCalls, 2);

      tabsBloc.emitState(TabsState(tabs: [firstTab()], currentTabIndex: 0));
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      await drag.handleDroppedOutside(firstTab(), tabsBloc);
      expect(runner.endCalls, 3);
    });
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

  group('מסירת הגרירה ל-Windows (Snap Layouts)', () {
    // ⚠️ המתנה **אמיתית**, ולא `FakeAsync`. המסירה נתלית על טיימר תקופתי
    // שכל פעימה שלו היא קריאת ערוץ, והתשובה חוזרת דרך ה-messenger
    // האסינכרוני — כלומר זמן מדומה לא היה מקדם את המסלול שנבדק.
    const settle = Duration(milliseconds: 260);

    const colors = DragPreviewColors(
      tab: Color(0xFF202020),
      border: Color(0xFF404040),
      text: Color(0xFFF0F0F0),
    );

    /// מתחיל גרירה כמו שהרצועה עושה, ומחזיר האם הגרירה בוטלה.
    bool Function() startDrag(OpenedTab tab) {
      var cancelled = false;
      drag.begin(
        tab,
        colors,
        tabsBloc: tabsBloc,
        cancelDrag: () => cancelled = true,
      );
      return () => cancelled;
    }

    test('יציאה מחלון המקור מוסרת את הגרירה ומבטלת את זו של Flutter', () async {
      // ⚠️ בלי הביטול, לולאת ההזזה של Windows לוכדת את העכבר ו-Flutter
      // לא יראה את השחרור — ה-`Draggable` נתקע לנצח, עם הכרטיסיה
      // מעומעמת במקומה.
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);

      final cancelled = startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.systemDragCalls, 1);
      expect(cancelled(), isTrue);
    });

    test('⚠️ אינה פותחת חלון בזמן הגרירה', () async {
      // זו נקודת התיקון מול הגרסה הקודמת, שפתחה מנוע Flutter מלא באמצע
      // הגרירה. מה שנמסר למערכת הוא חלון Win32 ריק שכבר קיים; החלון
      // האמיתי נפתח רק בשחרור.
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      final gate = Completer<void>();
      runner.systemDragGate = gate;

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.systemDragCalls, 1, reason: 'הגרירה נמסרה');
      expect(
        runner.openWindowCalls,
        0,
        reason: 'החלון נפתח בשחרור, לא בתחילת הגרירה',
      );
      expect(tabsBloc.events, isEmpty, reason: 'הכרטיסיה עוד בחלון המקור');

      // המשתמש שחרר.
      gate.complete();
      await Future<void>.delayed(settle);

      expect(runner.openWindowCalls, 1);
      expect(tabsBloc.events.whereType<RemoveTab>(), hasLength(1));
    });

    test('שחרור מוצמד פותח את החלון **במסגרת** שההצמדה נתנה', () async {
      // ⚠️ בלי זה ההצמדה שהמשתמש ראה נעלמת ברגע שהחלון האמיתי מופיע.
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      runner.systemDragResult = (
        ran: true,
        snapped: true,
        left: 960,
        top: 0,
        width: 960,
        height: 1040,
      );

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.openWindowCalls, 1);
      final bounds = runner.lastOpenArgs?['bounds'] as Map<Object?, Object?>?;
      expect(bounds?['left'], 960);
      expect(bounds?['width'], 960);
      expect(bounds?['height'], 1040);
      expect(
        runner.lastOpenArgs?['originX'],
        isNull,
        reason: 'מסגרת מדויקת דוחה את נקודת השחרור',
      );
      expect(tabsBloc.events.whereType<RemoveTab>(), hasLength(1));
    });

    test('שחרור בלי הצמדה: החלון נפתח בפינה שבה התצוגה נעצרה', () async {
      // ⚠️ שתי הצהרות בבדיקה אחת, ובמכוון — שתיהן היו באגים שהמשתמש ראה.
      //
      // 1. **לא** המסגרת: התצוגה היא בגודל כרטיסיה, ושימוש עיוור בה היה
      //    יוצר חלון אוצריא של 176×40.
      // 2. **לא** מיקום הסמן: ה-runner הזיז את החלון `-width + 100`
      //    מהנקודה שקיבל, ואחרי ההידוק לקצה המסך התוצאה הייתה קבועה —
      //    "גררתי ימינה והחלון נפתח בשמאל, טיפה מתחת למקור".
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      runner.systemDragResult = (
        ran: true,
        snapped: false,
        left: 500,
        top: 300,
        width: 176,
        height: 40,
      );

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.lastOpenArgs?['bounds'], isNull);
      expect(
        runner.lastOpenArgs?['originX'],
        500,
        reason: 'הפינה של התצוגה, ולא הסמן (100)',
      );
      expect(runner.lastOpenArgs?['originY'], 300);
    });

    test('שחרור מעל חלון אוצריא אחר מעביר אליו ואינו פותח חלון', () async {
      // ⚠️ זה מה שהיה נשבר בגרסה שפתחה חלון תוך כדי הגרירה: הדרך לחלון
      // ב' עוברת מעל שולחן העבודה. עכשיו ההחלטה נופלת בשחרור, ולכן
      // המסלול הזה שרד בלי השהיות.
      final peer = _FakePeer(2, accept: true)..register();
      addTearDown(peer.dispose);
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      runner.systemDragTarget = (slot: 2, isSelf: false, isShellTray: false);

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(peer.receivedTabs, 1);
      expect(runner.openWindowCalls, 0);
      expect(tabsBloc.events.whereType<RemoveTab>(), hasLength(1));
    });

    test('⚠️ הצמדה פותחת חלון גם כשחלון המקור תחת הסמן', () async {
      // זה היה באג נראה לעין: המשתמש ראה את מסדר החלונות נפתח, בחר אזור,
      // **ושום חלון לא נפתח**. האזור המוצמד מכסה בדרך כלל את חלון המקור
      // עצמו, ולכן `isSelf` יצא true והקוד ביטל בשקט.
      //
      // הצמדה היא החלטה מפורשת של המשתמש "החלון יהיה כאן", ולכן מה
      // שנמצא תחת הסמן באותו רגע חסר משמעות.
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      runner.systemDragTarget = (slot: 1, isSelf: true, isShellTray: false);
      runner.systemDragResult = (
        ran: true,
        snapped: true,
        left: 0,
        top: 0,
        width: 960,
        height: 1040,
      );

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.openWindowCalls, 1);
      expect(tabsBloc.events.whereType<RemoveTab>(), hasLength(1));
    });

    test('הצמדה גוברת גם על חלון אוצריא אחר שתחת הסמן', () async {
      // אותו היגיון: הצמדה אינה "העבר לחלון הזה" אלא "פתח חלון כאן".
      final peer = _FakePeer(2, accept: true)..register();
      addTearDown(peer.dispose);
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      runner.systemDragTarget = (slot: 2, isSelf: false, isShellTray: false);
      runner.systemDragResult = (
        ran: true,
        snapped: true,
        left: 960,
        top: 0,
        width: 960,
        height: 1040,
      );

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(peer.receivedTabs, 0);
      expect(runner.openWindowCalls, 1);
    });

    test('שחרור חזרה מעל חלון המקור מבוטל', () async {
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      runner.systemDragTarget = (slot: 1, isSelf: true, isShellTray: false);

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.openWindowCalls, 0);
      expect(tabsBloc.events, isEmpty);
      expect(runner.endCalls, 1);
    });

    test('שחרור מעל שורת המשימות מבוטל', () async {
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      runner.systemDragTarget = (slot: null, isSelf: false, isShellTray: true);

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.openWindowCalls, 0);
      expect(tabsBloc.events, isEmpty);
    });

    test('הכרטיסיה האחרונה אינה יוצאת לחלון חדש', () async {
      // אחרת נשאר חלון ריק ונפתח חדש — תזוזה בלי תועלת.
      tabsBloc.emitState(TabsState(tabs: [firstTab()], currentTabIndex: 0));
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.openWindowCalls, 0);
    });

    test('שחרור אחרי המסירה אינו מטפל בכרטיסיה פעמיים', () async {
      // ⚠️ הביטול ששלחנו ל-Flutter מגיע ל-`onDraggableCanceled`, ומשם
      // ל-`handleDroppedOutside`.
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      final tab = firstTab();

      startDrag(tab);
      await Future<void>.delayed(settle);
      drag.end();
      await drag.handleDroppedOutside(tab, tabsBloc);

      expect(runner.openWindowCalls, 1);
      expect(tabsBloc.events.whereType<RemoveTab>(), hasLength(1));
    });

    test('הסמן בתוך החלון אינו מוסר דבר', () async {
      runner.cursorTarget = (slot: 1, isSelf: true, isShellTray: false);

      startDrag(firstTab());
      await Future<void>.delayed(settle);

      expect(runner.systemDragCalls, 0);
    });

    test('בלי bloc אין מסירה — הגרירה נשארת כשהייתה', () async {
      // הרצועות מעבירות את שניהם; מי שלא, מקבל את ההתנהגות הקודמת ולא
      // מסירה חלקית שמאבדת כרטיסיה.
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);

      drag.begin(firstTab(), colors);
      await Future<void>.delayed(settle);

      expect(runner.systemDragCalls, 0);
      expect(tabsBloc.events, isEmpty);
    });
  });

  group('צילום הכרטיסיה', () {
    const colors = DragPreviewColors(
      tab: Color(0xFF202020),
      border: Color(0xFF404040),
      text: Color(0xFFF0F0F0),
    );

    /// תמונה אטומה קטנה — `_hasVisiblePixels` דורש פיקסל שאינו שקוף.
    Future<ui.Image> opaqueImage() {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        Uint8List.fromList(List<int>.filled(4 * 4 * 4, 0xFF)),
        4,
        4,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    }

    test('⚠️ נשלח מיד ולא נדחה ליציאה מהחלון', () async {
      // ⚠️ זו הגנה על שלושה באגים שדחיית השליחה יצרה בבת אחת:
      //
      // 1. `SetImage` שמגיע אחרי שהלולאה המודאלית התחילה מדלג על
      //    `Compose`, ולכן נגררה רק **כותרת** הכרטיסיה ולא המוק שלה.
      // 2. `PreviewSize` מחזיר את גודל היעד שנקבע ב-`SetImage`, ולכן
      //    ההשוואה בסוף הגרירה החזירה `snapped=true` כוזב.
      // 3. `snapped` גובר על היעד שתחת הסמן — כלומר שחרור מעל חלון
      //    אוצריא אחר פתח חלון **חדש** במקום להעביר אליו.
      runner.cursorTarget = (slot: 1, isSelf: true, isShellTray: false);
      drag.begin(firstTab(), colors, tabsBloc: tabsBloc);

      drag.applySnapshot(
        TabWindowPreview(
          image: await opaqueImage(),
          targetWidth: 1100,
          targetHeight: 760,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(runner.setImageCalls, 1, reason: 'הצילום נשלח בלי להמתין ליציאה');
      expect(runner.systemDragCalls, 0, reason: 'הסמן עוד בתוך החלון');
    });

    test('הצילום מקדים את המסירה למערכת', () async {
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
      final gate = Completer<void>();
      runner.systemDragGate = gate;

      drag.begin(firstTab(), colors, tabsBloc: tabsBloc, cancelDrag: () {});
      drag.applySnapshot(
        TabWindowPreview(
          image: await opaqueImage(),
          targetWidth: 1100,
          targetHeight: 760,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 260));
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(runner.setImageCalls, 1);
      expect(
        runner.imageArrivedAfterHandOff,
        isFalse,
        reason:
            'צילום שמגיע אחרי `dragOutToSystem` אינו מורכב, ומזייף '
            'את חישוב ה-snapped',
      );
    });
  });

  group('כרטיסיה שאינה שורדת סריאליזציה', () {
    const colors = DragPreviewColors(
      tab: Color(0xFF202020),
      border: Color(0xFF404040),
      text: Color(0xFFF0F0F0),
    );

    setUp(() {
      tabsBloc.emitState(
        TabsState(
          tabs: [_UnserializableTab(), firstTab()],
          currentTabIndex: 0,
        ),
      );
      runner.cursorTarget = (slot: null, isSelf: false, isShellTray: false);
    });

    test('נחסמת לפני כל ניסיון העברה', () async {
      await drag.handleDroppedOutside(tabsBloc.state.tabs.first, tabsBloc);

      expect(runner.openWindowCalls, 0);
      expect(tabsBloc.events, isEmpty);
    });

    test('⚠️ הגרירה נעצרת בפעימה הראשונה בחוץ ואינה חוזרת בלולאה', () async {
      // ⚠️ הבדיקה הזו היא ההגנה על H4: `canTransfer` בונה כרטיסיה מלאה —
      // BLoC, repository ומנויים — וקודם לכן היא נקראה מתוך לולאת הפעימות
      // של 60ms. כשהכרטיסיה נדחתה, `_handOffToSystem` חזר בלי לסמן דבר,
      // הטיימר המשיך, וכל 60ms נבנה BLoC חדש ונזרק כל עוד הסמן בחוץ.
      var cancelled = false;
      drag.begin(
        tabsBloc.state.tabs.first,
        colors,
        tabsBloc: tabsBloc,
        cancelDrag: () => cancelled = true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(cancelled, isTrue, reason: 'הגרירה בוטלה עם הודעה');
      expect(runner.systemDragCalls, 0, reason: 'לא נמסרה למערכת');
      expect(runner.openWindowCalls, 0);
      expect(tabsBloc.events, isEmpty);
      // הפעימות נמשכו 400ms; בלי העצירה היו כאן שש קריאות ומעלה.
      expect(runner.cursorQueries, lessThanOrEqualTo(2));
    });
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

  /// כמה פעימות של המעקב יצאו לנייטיב — מודד שהלולאה נעצרה.
  int cursorQueries = 0;

  /// כמה פעמים נשלח צילום הכרטיסיה, והאם הוא הגיע **אחרי** המסירה למערכת.
  int setImageCalls = 0;
  bool imageArrivedAfterHandOff = false;
  Map<Object?, Object?>? lastOpenArgs;

  /// היעד שהמערכת מדווחת עליו **בשחרור**, אם הוא שונה מזה שבזמן הגרירה.
  ///
  /// ⚠️ ההפרדה היא כל הנקודה: הגרירה עוברת מעל שולחן העבודה, וההחלטה
  /// נופלת לפי מה שתחת הסמן ברגע השחרור.
  ({int? slot, bool isSelf, bool isShellTray})? systemDragTarget;
  int systemDragCalls = 0;

  /// שער שמדמה את **החסימה** האמיתית: `dragOutToSystem` נענה רק כשהמשתמש
  /// שחרר, כי התשובה היא המסגרת הסופית. בלי השער המדומה עונה מיד, וכל
  /// המסלול היה מסתיים באותה מיקרו-משימה — כלומר "לא נפתח חלון בזמן
  /// הגרירה" היה עובר גם אם כן נפתח.
  Completer<void>? systemDragGate;
  ({
    bool ran,
    bool snapped,
    int left,
    int top,
    int width,
    int height,
  })
  systemDragResult = (
    ran: true,
    snapped: false,
    left: 0,
    top: 0,
    width: 176,
    height: 40,
  );

  /// ⚠️ שני מונים נפרדים, כי ההבחנה ביניהם היא כל התיקון: `freeze` משאיר
  /// את הרוח במקום השחרור עד שהחלון האמיתי מחליף אותה, ו-`end` מסתיר.
  int freezeCalls = 0;
  int endCalls = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MultiWindowService.channel, (call) async {
          switch (call.method) {
            case 'windowAtCursor':
              cursorQueries++;
              return {
                'slot': cursorTarget.slot,
                'isSelf': cursorTarget.isSelf,
                'isShellTray': cursorTarget.isShellTray,
                'x': 100,
                'y': 200,
              };
            case 'setTabDragImage':
              setImageCalls++;
              if (systemDragCalls > 0) imageArrivedAfterHandOff = true;
              return null;
            case 'dragOutToSystem':
              systemDragCalls++;
              await systemDragGate?.future;
              final target = systemDragTarget ?? cursorTarget;
              return {
                'ran': systemDragResult.ran,
                'snapped': systemDragResult.snapped,
                'left': systemDragResult.left,
                'top': systemDragResult.top,
                'width': systemDragResult.width,
                'height': systemDragResult.height,
                'slot': target.slot,
                'isSelf': target.isSelf,
                'isShellTray': target.isShellTray,
                'x': 100,
                'y': 200,
              };
            case 'openWindow':
              openWindowCalls++;
              lastOpenArgs = call.arguments as Map<Object?, Object?>?;
              return openWindowResult;
            case 'freezeTabDrag':
              freezeCalls++;
              return null;
            case 'endTabDrag':
              endCalls++;
              return null;
            case 'windowCount':
              return {'count': 1, 'max': 4, 'engines': 1};
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
