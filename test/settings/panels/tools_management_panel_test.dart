import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:otzaria/plugins/bloc/plugin_system_bloc.dart';
import 'package:otzaria/plugins/bloc/plugin_system_event.dart';
import 'package:otzaria/plugins/bloc/plugin_system_state.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/settings/panels/tools_management_panel.dart';
import 'package:otzaria/tools/built_in_tools_catalog.dart';

// ─── Test doubles ─────────────────────────────────────────────────────────────

class _FakeSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  final List<SettingsEvent> dispatched = [];
  _FakeSettingsBloc({
    Set<String> hidden = const <String>{},
    Set<String> pinnedToNav = const <String>{},
  }) : super(SettingsState.initial().copyWith(
          hiddenBuiltInToolIds: hidden,
          builtInToolsPinnedToNavRail: pinnedToNav,
        )) {
    on<SettingsEvent>((event, emit) {
      dispatched.add(event);
      if (event is UpdateHiddenBuiltInToolIds) {
        emit(state.copyWith(hiddenBuiltInToolIds: event.hiddenBuiltInToolIds));
      } else if (event is UpdateBuiltInToolsPinnedToNavRail) {
        emit(state.copyWith(
            builtInToolsPinnedToNavRail: event.builtInToolsPinnedToNavRail));
      }
    });
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePluginSystemBloc extends Bloc<PluginSystemEvent, PluginSystemState>
    implements PluginSystemBloc {
  final List<PluginSystemEvent> dispatched = [];
  _FakePluginSystemBloc(List<InstalledPlugin> plugins)
      : super(PluginSystemLoaded(plugins)) {
    on<PluginSystemEvent>((event, emit) {
      dispatched.add(event);
    });
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

PluginManifest _manifest({
  String id = 'p',
  List<String> permissions = const [],
  bool networkEnabled = false,
}) {
  return PluginManifest.fromJson({
    'schemaVersion': 1,
    'id': id,
    'name': id,
    'version': '1.0.0',
    'entrypoint': 'index.html',
    'permissions': permissions,
    'networkEnabled': networkEnabled,
    'contributes': {
      'toolTab': {'title': id},
    },
  });
}

InstalledPlugin _plugin({
  required String id,
  String name = 'plugin',
  bool enabled = true,
  bool hidden = false,
  bool pinnedToNavRail = false,
  bool networkAccessGranted = false,
  bool runOnStartupGranted = false,
  List<String> permissions = const [],
}) {
  return InstalledPlugin(
    pluginId: id,
    name: name,
    version: '1.0.0',
    installPath: '/x/$id',
    entrypointPath: 'index.html',
    enabled: enabled,
    pinned: true,
    pinnedToNavRail: pinnedToNavRail,
    showInTools: !hidden,
    networkAccessGranted: networkAccessGranted,
    runOnStartupGranted: runOnStartupGranted,
    manifest: _manifest(id: id, permissions: permissions),
    installedAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Widget _wrap({
  required SettingsBloc settingsBloc,
  required PluginSystemBloc pluginBloc,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
            BlocProvider<PluginSystemBloc>.value(value: pluginBloc),
          ],
          child: const SingleChildScrollView(
            child: ToolsManagementPanel(),
          ),
        ),
      ),
    ),
  );
}

/// פותח/סוגר את אזור "כלים מובנים" דרך שורת הסיכום בכרטיס הלבן.
Future<void> _expandBuiltIn(WidgetTester tester) async {
  await tester.tap(find.text('רשימת הכלים'));
  await tester.pumpAndSettle();
}

/// נכנס למצב בחירה מרובה של תוספים על-ידי לחיצה על "בחירה".
Future<void> _enterSelectionMode(WidgetTester tester) async {
  await tester.tap(find.text('בחירה'));
  await tester.pumpAndSettle();
}

/// בוחר תוסף על-פי שמו (מניח שמצב בחירה כבר פעיל).
Future<void> _selectPlugin(WidgetTester tester, String name) async {
  await tester.tap(find.textContaining(name));
  await tester.pumpAndSettle();
}

/// מאתר לחצן (לפי tooltip) בתוך שורת הכלי שמכילה [label].
Finder _rowButton(String label, String tooltip) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(ListTile),
      ),
      matching: find.byTooltip(tooltip),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  testWidgets(
    'built-in section is collapsed by default and expands on tap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: _FakePluginSystemBloc(const []),
      ));
      await tester.pumpAndSettle();

      // כותרת האזור מופיעה, אבל התוכן סגור.
      expect(find.text('כלים מובנים'), findsOneWidget);
      expect(find.text('לוח שנה'), findsNothing);

      await _expandBuiltIn(tester);

      // לאחר פתיחה — כל הכלים מהקטלוג מופיעים.
      expect(find.text('לוח שנה'), findsOneWidget);
      expect(find.text('גימטריה'), findsOneWidget);
      expect(find.text('שמור וזכור'), findsOneWidget);
    },
  );

  testWidgets(
    'plugins card is hidden when no plugins are installed',
    (tester) async {
      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: _FakePluginSystemBloc(const []),
      ));
      await tester.pumpAndSettle();

      expect(find.text('תוספים מותקנים'), findsNothing);
    },
  );

  testWidgets(
    'plugins section shows header and plugin rows when plugins are installed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: _FakePluginSystemBloc([
          _plugin(id: 'p1', name: 'תוסף-A'),
        ]),
      ));
      await tester.pumpAndSettle();

      // הכותרת והשורה גלויים מיד — אין קיפול באזור התוספים.
      expect(find.text('תוספים מותקנים'), findsOneWidget);
      expect(find.textContaining('תוסף-A'), findsOneWidget);
    },
  );

  testWidgets(
    'built-in tool rows have no checkboxes (button-based actions)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: _FakePluginSystemBloc(const []),
      ));
      await tester.pumpAndSettle();
      await _expandBuiltIn(tester);

      // אין תיבות סימון באזור הכלים המובנים, אבל יש לחצני הסתרה/הצמדה —
      // אחד לכל כלי בקטלוג.
      final toolCount = kBuiltInToolsCatalog.length;
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byTooltip('הסתר מהממשק'), findsNWidgets(toolCount));
      expect(find.byTooltip('הצמד לסרגל הניווט'), findsNWidgets(toolCount));
      // אין סרגל בחירה מרובה (אין "נבחרו").
      expect(find.textContaining('נבחרו'), findsNothing);
    },
  );

  testWidgets(
    'tapping the hide button on a built-in tool dispatches '
    'UpdateHiddenBuiltInToolIds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settingsBloc = _FakeSettingsBloc();

      await tester.pumpWidget(_wrap(
        settingsBloc: settingsBloc,
        pluginBloc: _FakePluginSystemBloc(const []),
      ));
      await tester.pumpAndSettle();
      await _expandBuiltIn(tester);

      await tester.tap(_rowButton('לוח שנה', 'הסתר מהממשק'));
      await tester.pumpAndSettle();

      final updates = settingsBloc.dispatched
          .whereType<UpdateHiddenBuiltInToolIds>()
          .toList();
      expect(updates, hasLength(1));
      expect(updates.single.hiddenBuiltInToolIds, contains('builtin.calendar'));
    },
  );

  testWidgets(
    'tapping the pin button on a built-in tool dispatches '
    'UpdateBuiltInToolsPinnedToNavRail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settingsBloc = _FakeSettingsBloc();

      await tester.pumpWidget(_wrap(
        settingsBloc: settingsBloc,
        pluginBloc: _FakePluginSystemBloc(const []),
      ));
      await tester.pumpAndSettle();
      await _expandBuiltIn(tester);

      await tester.tap(_rowButton('גימטריה', 'הצמד לסרגל הניווט'));
      await tester.pumpAndSettle();

      final updates = settingsBloc.dispatched
          .whereType<UpdateBuiltInToolsPinnedToNavRail>()
          .toList();
      expect(updates, hasLength(1));
      expect(updates.single.builtInToolsPinnedToNavRail,
          contains('builtin.gematria'));
    },
  );

  testWidgets(
    'a hidden built-in tool shows the "show" button and the "מוסתר" badge',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settingsBloc = _FakeSettingsBloc(
        hidden: const {'builtin.calendar'},
      );

      await tester.pumpWidget(_wrap(
        settingsBloc: settingsBloc,
        pluginBloc: _FakePluginSystemBloc(const []),
      ));
      await tester.pumpAndSettle();
      await _expandBuiltIn(tester);

      // הכלי עדיין מופיע בטבלה — רק הוא מוסתר מהממשק הראשי.
      expect(find.text('לוח שנה'), findsOneWidget);
      // תגית "מוסתר" (אייקון עם tooltip) צריכה להופיע.
      expect(find.byTooltip('מוסתר'), findsOneWidget);
      // הלחצן בשורת לוח-שנה צריך להציע "הצג בממשק" (ולא "הסתר").
      expect(_rowButton('לוח שנה', 'הצג בממשק'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a plugin reveals the action bar with plugin actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: _FakePluginSystemBloc([
          _plugin(id: 'p1', name: 'תוסף-A'),
        ]),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('נבחרו'), findsNothing);

      await _enterSelectionMode(tester);
      await _selectPlugin(tester, 'תוסף-A');

      expect(find.text('1 נבחרו'), findsOneWidget);
      expect(find.text('מחק'), findsOneWidget);
      expect(find.text('השבת'), findsOneWidget);
    },
  );

  testWidgets(
    '"בחר הכל" מופיע במצב בחירה ובוחר את כל התוספים',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: _FakePluginSystemBloc([
          _plugin(id: 'p1', name: 'תוסף-A'),
          _plugin(id: 'p2', name: 'תוסף-B'),
        ]),
      ));
      await tester.pumpAndSettle();
      await _enterSelectionMode(tester);

      // "בחר הכל" גלוי מיד עם כניסה למצב בחירה, ללא צורך לבחור תוסף קודם.
      expect(find.text('בחר הכל'), findsOneWidget);
      expect(find.text('0 נבחרו'), findsOneWidget);

      // לחיצה — כל התוספים נבחרים, וסרגל הפעולות מופיע.
      await tester.tap(find.text('בחר הכל'));
      await tester.pumpAndSettle();
      expect(find.text('2 נבחרו'), findsOneWidget);

      // לחיצה חוזרת — נשאר עם כל הבחירות (addAll לא מבטל).
      await tester.tap(find.text('בחר הכל'));
      await tester.pumpAndSettle();
      expect(find.text('2 נבחרו'), findsOneWidget);
    },
  );

  testWidgets(
    'pressing "ביטול" exits selection mode and clears the selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: _FakePluginSystemBloc([
          _plugin(id: 'p1', name: 'תוסף-A'),
        ]),
      ));
      await tester.pumpAndSettle();
      await _enterSelectionMode(tester);
      await _selectPlugin(tester, 'תוסף-A');
      expect(find.text('1 נבחרו'), findsOneWidget);

      // לחיצה על "ביטול" — יוצאת ממצב בחירה ומנקה את הבחירה.
      await tester.tap(find.text('ביטול'));
      await tester.pumpAndSettle();

      expect(find.textContaining('נבחרו'), findsNothing);
      // חזרנו למצב רגיל — כפתור "בחירה" מופיע שוב.
      expect(find.text('בחירה'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping enable/disable on selected plugin dispatches relevant event',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pluginBloc = _FakePluginSystemBloc([
        _plugin(id: 'p1', name: 'תוסף-A'),
      ]);

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: pluginBloc,
      ));
      await tester.pumpAndSettle();
      await _enterSelectionMode(tester);
      await _selectPlugin(tester, 'תוסף-A');

      await tester.tap(find.text('השבת'));
      await tester.pumpAndSettle();

      final disableEvents =
          pluginBloc.dispatched.whereType<DisablePluginRequested>().toList();
      expect(disableEvents, hasLength(1));
      expect(disableEvents.single.pluginId, 'p1');
    },
  );

  testWidgets(
    'tapping "הסתר מכלים" on a plugin dispatches SetPluginShowInToolsRequested(false)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pluginBloc = _FakePluginSystemBloc([
        _plugin(id: 'p1', name: 'תוסף-A'),
      ]);

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: pluginBloc,
      ));
      await tester.pumpAndSettle();
      await _enterSelectionMode(tester);
      await _selectPlugin(tester, 'תוסף-A');

      await tester.tap(find.text('הסתר'));
      await tester.pumpAndSettle();

      final events =
          pluginBloc.dispatched.whereType<SetPluginShowInToolsRequested>().toList();
      expect(events, hasLength(1));
      expect(events.single.pluginId, 'p1');
      expect(events.single.showInTools, isFalse);
    },
  );

  testWidgets(
    'network access button — tapping "גישה לרשת" dispatches granted:true',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pluginBloc = _FakePluginSystemBloc([
        _plugin(
          id: 'p1',
          name: 'תוסף-A',
          permissions: const ['network.access'],
          networkAccessGranted: false,
        ),
      ]);

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: pluginBloc,
      ));
      await tester.pumpAndSettle();
      await _enterSelectionMode(tester);
      await _selectPlugin(tester, 'תוסף-A');

      // הכפתור מציג "גישה לרשת" ולוחץ ישירות — אין תפריט
      await tester.tap(find.text('גישה לרשת'));
      await tester.pumpAndSettle();

      final events = pluginBloc.dispatched
          .whereType<SetPluginPermissionRequested>()
          .where((e) => e.permission == 'network.access')
          .toList();
      expect(events, hasLength(1));
      expect(events.single.granted, isTrue);
    },
  );

  testWidgets(
    'network access button — tapping "דחיה מהרשת" dispatches granted:false',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pluginBloc = _FakePluginSystemBloc([
        _plugin(
          id: 'p1',
          name: 'תוסף-A',
          permissions: const ['network.access'],
          networkAccessGranted: true,
        ),
      ]);

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: pluginBloc,
      ));
      await tester.pumpAndSettle();
      await _enterSelectionMode(tester);
      await _selectPlugin(tester, 'תוסף-A');

      // כשהגישה מוענקת — הכפתור מציג "דחיה מהרשת" ושולח granted:false
      await tester.tap(find.text('דחיה מהרשת'));
      await tester.pumpAndSettle();

      final events = pluginBloc.dispatched
          .whereType<SetPluginPermissionRequested>()
          .where((e) => e.permission == 'network.access')
          .toList();
      expect(events, hasLength(1));
      expect(events.single.granted, isFalse,
          reason: 'revoke must send granted:false');
    },
  );

  testWidgets(
    'dragging a plugin row to another row dispatches ReorderPluginsRequested',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pluginBloc = _FakePluginSystemBloc([
        _plugin(id: 'p1', name: 'תוסף-A'),
        _plugin(id: 'p2', name: 'תוסף-B'),
      ]);

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: pluginBloc,
      ));
      await tester.pumpAndSettle();

      final handles =
          find.byIcon(FluentIcons.re_order_dots_vertical_24_regular);
      expect(handles, findsNWidgets(2));

      final srcCenter = tester.getCenter(handles.first);
      final dstCenter = tester.getCenter(handles.last);

      await tester.timedDrag(
        handles.first,
        Offset(0, dstCenter.dy - srcCenter.dy),
        const Duration(milliseconds: 200),
      );
      await tester.pumpAndSettle();

      final events =
          pluginBloc.dispatched.whereType<ReorderPluginsRequested>().toList();
      expect(events, hasLength(1));
      // p1 (index 0) dragged to p2 (index 1) → p1 inserted after p2
      expect(events.single.orderedPluginIds, orderedEquals(['p2', 'p1']));
    },
  );

  testWidgets(
    'startup button — tapping "טעינה רגילה" dispatches granted:false',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pluginBloc = _FakePluginSystemBloc([
        _plugin(
          id: 'p1',
          name: 'תוסף-A',
          permissions: const ['app.run_on_startup'],
          runOnStartupGranted: true,
        ),
      ]);

      await tester.pumpWidget(_wrap(
        settingsBloc: _FakeSettingsBloc(),
        pluginBloc: pluginBloc,
      ));
      await tester.pumpAndSettle();
      await _enterSelectionMode(tester);
      await _selectPlugin(tester, 'תוסף-A');

      // כשהטעינה בעלייה מופעלת — הכפתור מציג "טעינה רגילה" ושולח granted:false
      await tester.tap(find.text('טעינה רגילה'));
      await tester.pumpAndSettle();

      final events = pluginBloc.dispatched
          .whereType<SetPluginPermissionRequested>()
          .where((e) => e.permission == 'app.run_on_startup')
          .toList();
      expect(events, hasLength(1));
      expect(events.single.granted, isFalse);
    },
  );

  testWidgets(
    'a pinned built-in tool shows "בסרגל ניווט" badge and "הסר מסרגל הניווט" button',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settingsBloc = _FakeSettingsBloc(
        pinnedToNav: const {'builtin.calendar'},
      );

      await tester.pumpWidget(_wrap(
        settingsBloc: settingsBloc,
        pluginBloc: _FakePluginSystemBloc(const []),
      ));
      await tester.pumpAndSettle();
      await _expandBuiltIn(tester);

      expect(find.text('לוח שנה'), findsOneWidget);
      // _badge מציג אייקון בלבד; הטקסט חי כ-Tooltip.message — נחפש byTooltip.
      // ה-Stack מרנדר placeholder בלתי-נראה + badge נראה — שניהם נושאים את ה-tooltip.
      final calendarRow = find.ancestor(
        of: find.text('לוח שנה'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
            of: calendarRow, matching: find.byTooltip('בסרגל ניווט')),
        findsNWidgets(2),
      );
      expect(_rowButton('לוח שנה', 'הסר מסרגל הניווט'), findsOneWidget);
    },
  );

  testWidgets(
    'built-in tool row height stays constant across all badge states',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<double> measureCalendarRowHeight(_FakeSettingsBloc bloc) async {
        await tester.pumpWidget(_wrap(
          settingsBloc: bloc,
          pluginBloc: _FakePluginSystemBloc(const []),
        ));
        await tester.pumpAndSettle();
        await _expandBuiltIn(tester);
        // flash notifier עשוי לפתוח את הסעיף אוטומטית לפני ה-tap ואז ה-tap סוגר אותו
        if (find.text(kBuiltInToolsCatalog[0].label).evaluate().isEmpty) {
          await _expandBuiltIn(tester);
        }
        // גובה שורת לוח-שנה = מרחק בין top של title שלה ל-top של title של הכלי הבא
        final calendarTop =
            tester.getTopLeft(find.text(kBuiltInToolsCatalog[0].label)).dy;
        final nextToolTop =
            tester.getTopLeft(find.text(kBuiltInToolsCatalog[1].label)).dy;
        return nextToolTop - calendarTop;
      }

      final noBadges = await measureCalendarRowHeight(_FakeSettingsBloc());
      final hiddenOnly = await measureCalendarRowHeight(
        _FakeSettingsBloc(hidden: const {'builtin.calendar'}),
      );
      final pinnedOnly = await measureCalendarRowHeight(
        _FakeSettingsBloc(pinnedToNav: const {'builtin.calendar'}),
      );
      final both = await measureCalendarRowHeight(
        _FakeSettingsBloc(
          hidden: const {'builtin.calendar'},
          pinnedToNav: const {'builtin.calendar'},
        ),
      );

      expect(hiddenOnly, noBadges,
          reason: '"מוסתר" badge must not change row height');
      expect(pinnedOnly, noBadges,
          reason: '"בסרגל ניווט" badge must not change row height');
      expect(both, noBadges,
          reason: 'both badges together must not change row height');
    },
  );
}
