import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/commentators_tab.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_event.dart';
import 'package:otzaria/navigation/bloc/navigation_state.dart';
import 'package:otzaria/navigation/view/custom_title_bar.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_event.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../helpers/memory_settings_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  testWidgets('tooltip של TextBookTab כולל את כותרת המיקום בפועל',
      (tester) async {
    final tab = _makeTextTab('ספר א', currentTitle: 'פרק א');
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [tab], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());

    addTearDown(() async {
      tab.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(1200, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    expect(find.byTooltip('ספר א, פרק א'), findsOneWidget);
  });

  testWidgets('אייקון pin מוצג כשהכרטיסיה מוצמדת', (tester) async {
    final tab = _makeTextTab('ספר א');
    tab.isPinned = true;
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [tab], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());

    addTearDown(() async {
      tab.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(1200, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == FluentIcons.pin_24_filled,
      ),
      findsOneWidget,
    );
  });

  testWidgets('אייקון pin מוסתר כשהכרטיסיה אינה מוצמדת', (tester) async {
    final tab = _makeTextTab('ספר א');
    // isPinned = false כברירת מחדל
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [tab], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());

    addTearDown(() async {
      tab.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(1200, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == FluentIcons.pin_24_filled,
      ),
      findsNothing,
    );
  });

  testWidgets('כרטיסיות אינן עטופות ב-SizedBox בעל רוחב קבוע', (tester) async {
    final tab1 = _makeTextTab('ספר קצר');
    final tab2 = _makeTextTab('ספר עם שם ארוך מאוד שנמשך הרחק');
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [tab1, tab2], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());

    addTearDown(() async {
      tab1.dispose();
      tab2.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(900, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    // אין SizedBox בעל רוחב קבוע עוטף Listener (שימוש ב-tabWidth שהוסר)
    final fixedWidthBoxes = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((box) =>
            box.width != null &&
            box.width! >= 72 &&
            box.width! <= 200 &&
            box.child is Listener)
        .toList();

    expect(fixedWidthBoxes, isEmpty,
        reason: 'כרטיסיות צריכות להיות ברוחב טבעי, לא קבוע שוויוני');
  });

  testWidgets('CommentatorsTab לא מפיל את שורת הכותרת', (tester) async {
    final sourceTab = _makeTextTab('ספר א', currentTitle: 'פרק א');
    final tab = CommentatorsTab(sourceTab: sourceTab);
    final tabsBloc = _TestTabsBloc(
      TabsState(tabs: [tab], currentTabIndex: 0),
    );
    final navigationBloc = _TestNavigationBloc(
      const NavigationState(currentScreen: Screen.reading),
    );
    final settingsBloc = _TestSettingsBloc(SettingsState.initial());

    addTearDown(() async {
      tab.dispose();
      sourceTab.dispose();
      await tabsBloc.close();
      await navigationBloc.close();
      await settingsBloc.close();
    });

    await _setSurfaceSize(tester, const Size(1200, 800));
    await _pumpTitleBar(
      tester,
      tabsBloc: tabsBloc,
      navigationBloc: navigationBloc,
      settingsBloc: settingsBloc,
    );

    expect(find.text('מפרשים | ספר א'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('בחירה וגרירת-סידור של טאבים', () {
    testWidgets('לחיצה על טאב שולחת SetCurrentTab עם האינדקס שלו',
        (tester) async {
      final first = _makeTextTab('ספר א');
      final second = _makeTextTab('ספר ב');
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: [first, second], currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        first.dispose();
        second.dispose();
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(1200, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );

      // הבחירה מתבצעת ב-onPointerDown (Listener פסיבי), כך שקליק רגיל מספיק.
      // warnIfMissed:false כי ה-drag recognizer של ReorderableListView עשוי
      // לתפוס את ה-tap; pumpAndSettle מנקה את ה-timer של אנימציית הגרירה.
      await tester.tap(find.text('ספר ב'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final selected = tabsBloc.addedEvents.whereType<SetCurrentTab>().toList();
      expect(selected, isNotEmpty,
          reason: 'לחיצה על טאב צריכה לשלוח SetCurrentTab');
      expect(selected.last.index, 1, reason: 'האינדקס הנבחר הוא של הטאב שנלחץ');
    });

    testWidgets('גרירת טאב בוחרת אותו (כמו כרום) ושולחת MoveTab לסידור מחדש',
        (tester) async {
      final first = _makeTextTab('ספר א');
      final second = _makeTextTab('ספר ב');
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: [first, second], currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        first.dispose();
        second.dispose();
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(1200, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );

      // גרירת הטאב השני (אינדקס 1) לכיוון הטאב הראשון. ה-drag listener מיידי
      // (לא long-press), כך ש-startGesture + moveBy מתחילים reorder.
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('ספר ב')));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();

      // onReorderStart בוחר את הטאב הנגרר.
      expect(
        tabsBloc.addedEvents.whereType<SetCurrentTab>().map((e) => e.index),
        contains(1),
        reason: 'תחילת גרירה בוחרת את הטאב הנגרר (אינדקס 1)',
      );
      // onReorderItem שולח MoveTab עם הטאב הנכון.
      final moves = tabsBloc.addedEvents.whereType<MoveTab>().toList();
      expect(moves, isNotEmpty, reason: 'שחרור הגרירה צריך לשלוח MoveTab');
      expect(moves.last.tab, same(second),
          reason: 'הטאב שמועבר הוא הטאב שנגרר');
    });

    testWidgets('כשהטאבים גולשים מעבר לרוחב — חיצי הגלילה מופיעים בטעינה',
        (tester) async {
      // הרבה טאבים ברוחב מצומצם → overflow כבר בטעינה הראשונית, לפני כל גלילה.
      final tabs = List.generate(15, (i) => _makeTextTab('ספר מספר $i'));
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: tabs, currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        for (final t in tabs) {
          t.dispose();
        }
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(1200, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );
      // pumpAndSettle מאפשר ל-ScrollMetricsNotification + ה-setState הדחוי
      // (post-frame) להציג את החיצים גם בלי שום אירוע גלילה.
      await tester.pumpAndSettle();

      // לפחות חץ אחד מופיע (הכיוון תלוי-RTL/מצב גלילה).
      final hasArrow = find
              .byIcon(FluentIcons.chevron_left_24_regular)
              .evaluate()
              .isNotEmpty ||
          find
              .byIcon(FluentIcons.chevron_right_24_regular)
              .evaluate()
              .isNotEmpty;
      expect(hasArrow, isTrue,
          reason: 'overflow של טאבים צריך להציג חיצי גלילה כבר בטעינה');
    });
  });

  group('גלילה אוטומטית לטאב הנבחר', () {
    testWidgets('בטעינה ראשונית עם טאב נבחר מחוץ לתצוגה — נגלל אליו',
        (tester) async {
      // הרבה טאבים שגולשים מעבר לרוחב, והטאב הנבחר הוא האחרון (מחוץ לתצוגה
      // ב-offset 0). ללא גלילה אוטומטית הוא היה נשאר גלול מחוץ לראייה.
      final tabs = List.generate(20, (i) => _makeTextTab('ספר מספר $i'));
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: tabs, currentTabIndex: 19),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        for (final t in tabs) {
          t.dispose();
        }
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(1200, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );
      await tester.pumpAndSettle();

      // שורת הטאבים נגללה מ-offset 0 כדי להראות את הטאב הנבחר.
      final scrollableFinder = find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(Scrollable),
      );
      final position =
          tester.state<ScrollableState>(scrollableFinder.first).position;
      expect(position.pixels, greaterThan(0),
          reason: 'הטאב הנבחר האחרון מחוץ לתצוגה צריך לגרום לגלילה');

      // והטאב הנבחר אכן רונדר (נכנס לתחום אחרי הגלילה).
      expect(find.text('ספר מספר 19'), findsOneWidget,
          reason: 'הטאב הנבחר צריך להיות גלוי אחרי הגלילה האוטומטית');
    });

    testWidgets('שינוי בחירה אחרי הטעינה הראשונית גם גורר גלילה',
        (tester) async {
      // מאמת שהמנגנון אינו חד-פעמי: גם rebuild עוקב (כאן — בחירת טאב אחר דרך
      // עדכון ה-state) מפעיל את הגלילה האוטומטית.
      final tabs = List.generate(20, (i) => _makeTextTab('ספר מספר $i'));
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: tabs, currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        for (final t in tabs) {
          t.dispose();
        }
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(1200, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(Scrollable),
      );
      // הטאב הראשון נבחר → אין גלילה בטעינה.
      expect(
          tester.state<ScrollableState>(scrollableFinder.first).position.pixels,
          0);

      // בחירת הטאב האחרון אחרי הטעינה.
      tabsBloc.emitState(TabsState(tabs: tabs, currentTabIndex: 19));
      await tester.pumpAndSettle();

      expect(
        tester.state<ScrollableState>(scrollableFinder.first).position.pixels,
        greaterThan(0),
        reason: 'בחירת טאב נסתר אחרי הטעינה צריכה לגלול אליו',
      );
    });

    testWidgets('כיווץ רוחב המסך (resize) שמוציא את הטאב הנבחר — נגלל אליו',
        (tester) async {
      // מסך רחב מאוד שבו כל הטאבים נכנסים; הטאב הנבחר האחרון נראה ללא גלילה.
      // כיווץ הרוחב יוצר overflow ומוציא אותו — ובלי תלות בשינוי אינדקס,
      // הגלילה האוטומטית צריכה להחזירו לתצוגה.
      final tabs = List.generate(15, (i) => _makeTextTab('ספר מספר $i'));
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: tabs, currentTabIndex: 14),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        for (final t in tabs) {
          t.dispose();
        }
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      tester.view.physicalSize = const Size(4000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // בנייה ברוחב מלא (ללא SizedBox קבוע) כדי ש-resize ישפיע על שורת הטאבים.
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<TabsBloc>.value(value: tabsBloc),
            BlocProvider<NavigationBloc>.value(value: navigationBloc),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CustomTitleBar(onReadingSettingsPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(Scrollable),
      );
      // ברוחב 4000 הכל נכנס — אין גלילה.
      expect(
          tester.state<ScrollableState>(scrollableFinder.first).position.pixels,
          0,
          reason: 'במסך רחב מאוד אין overflow');

      // כיווץ ל-900px (עדיין landscape) — נוצר overflow והטאב האחרון יוצא.
      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpAndSettle();

      expect(
        tester.state<ScrollableState>(scrollableFinder.first).position.pixels,
        greaterThan(0),
        reason: 'כיווץ הרוחב מוציא את הטאב הנבחר → גלילה אוטומטית אליו',
      );
    });

    testWidgets('טאב נבחר ראשון — אין גלילה מיותרת (נשאר ב-offset 0)',
        (tester) async {
      final tabs = List.generate(20, (i) => _makeTextTab('ספר מספר $i'));
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: tabs, currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        for (final t in tabs) {
          t.dispose();
        }
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(1200, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(Scrollable),
      );
      final position =
          tester.state<ScrollableState>(scrollableFinder.first).position;
      expect(position.pixels, 0,
          reason: 'הטאב הראשון כבר נראה — אין צורך לגלול');
    });
  });

  group('פריסת מסך צר (portrait) — טאבים בשורה תחתונה', () {
    testWidgets('landscape: הטאבים באותה שורה של כפתורי הפעולה',
        (tester) async {
      final tab = _makeTextTab('ספר א');
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: [tab], currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        tab.dispose();
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(1200, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );

      final tabsBarSize = tester.getSize(find.byType(ReorderableListView));
      expect(tabsBarSize.height, lessThanOrEqualTo(40),
          reason: 'במצב רחב הטאבים בתוך שורת הכותרת 40px');

      final tabsTop = tester.getTopLeft(find.byType(ReorderableListView)).dy;
      expect(tabsTop, lessThan(40),
          reason: 'בלנדסקייפ הטאבים בשורה העליונה (y < 40)');
    });

    testWidgets('portrait: הטאבים בשורה תחתונה מתחת לשורת הכותרת',
        (tester) async {
      final tab = _makeTextTab('ספר א');
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: [tab], currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        tab.dispose();
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(400, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );

      final tabsTop = tester.getTopLeft(find.byType(ReorderableListView)).dy;
      expect(tabsTop, greaterThanOrEqualTo(40),
          reason:
              'ב-portrait הטאבים בשורה תחתונה (y ≥ 40, כי השורה העליונה היא 40)');
    });

    testWidgets('portrait: הטאבים מקבלים רוחב מלא ולא נדחסים', (tester) async {
      final first = _makeTextTab('ספר א');
      final second = _makeTextTab('ספר ב');
      final tabsBloc = _TestTabsBloc(
        TabsState(tabs: [first, second], currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        first.dispose();
        second.dispose();
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(400, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );

      final tabsBarWidth =
          tester.getSize(find.byType(ReorderableListView)).width;
      expect(tabsBarWidth, greaterThan(300),
          reason: 'בשורה התחתונה הטאבים מקבלים את הרוחב כמעט-מלא');
    });

    testWidgets('portrait בלי טאבים פתוחים: השורה התחתונה לא מופיעה',
        (tester) async {
      final tabsBloc = _TestTabsBloc(
        const TabsState(tabs: [], currentTabIndex: 0),
      );
      final navigationBloc = _TestNavigationBloc(
        const NavigationState(currentScreen: Screen.reading),
      );
      final settingsBloc = _TestSettingsBloc(SettingsState.initial());

      addTearDown(() async {
        await tabsBloc.close();
        await navigationBloc.close();
        await settingsBloc.close();
      });

      await _setSurfaceSize(tester, const Size(400, 800));
      await _pumpTitleBar(
        tester,
        tabsBloc: tabsBloc,
        navigationBloc: navigationBloc,
        settingsBloc: settingsBloc,
      );

      expect(find.byType(ReorderableListView), findsNothing);
    });
  });
}

Future<void> _pumpTitleBar(
  WidgetTester tester, {
  required TabsBloc tabsBloc,
  required NavigationBloc navigationBloc,
  required SettingsBloc settingsBloc,
}) async {
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<TabsBloc>.value(value: tabsBloc),
        BlocProvider<NavigationBloc>.value(value: navigationBloc),
        BlocProvider<SettingsBloc>.value(value: settingsBloc),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: CustomTitleBar(
              onReadingSettingsPressed: () {},
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

TextBookTab _makeTextTab(String title, {String currentTitle = ''}) {
  final book = TextBook(title: title);
  final bloc = _TestTextBookBloc(
    TextBookLoaded(
      book: book,
      showLeftPane: false,
      content: const ['שורה א'],
      fontSize: 18,
      showSplitView: false,
      activeCommentators: const [],
      commentatorGroups: const [],
      availableCommentators: const [],
      links: const [],
      visibleLinks: const [],
      linksByLine: const {},
      tableOfContents: const [],
      removeNikud: false,
      removePunctuation: false,
      visibleIndices: const [0],
      selectedIndex: 0,
      pinLeftPane: false,
      searchText: '',
      currentTitle: currentTitle,
      scrollController: ItemScrollController(),
      positionsListener: ItemPositionsListener.create(),
    ),
  );

  final tab = TextBookTab(
    book: book,
    index: 0,
    blocOverride: bloc,
  );
  tab.currentTitle.value = currentTitle;
  return tab;
}

class _TestTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TestTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTabsBloc extends Cubit<TabsState> implements TabsBloc {
  _TestTabsBloc(super.initialState);

  /// מתעד את כל ה-events שנשלחו, לבדיקת בחירה/סידור-מחדש של טאבים.
  final List<TabsEvent> addedEvents = [];

  /// מאפשר לטסט לדמות שינוי מצב (בחירה/החלפת רשימת טאבים) אחרי הטעינה.
  void emitState(TabsState state) => emit(state);

  @override
  void add(TabsEvent event) => addedEvents.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestNavigationBloc extends Cubit<NavigationState>
    implements NavigationBloc {
  _TestNavigationBloc(super.initialState);

  @override
  void add(NavigationEvent event) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _TestSettingsBloc(super.initialState) {
    on<SettingsEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
