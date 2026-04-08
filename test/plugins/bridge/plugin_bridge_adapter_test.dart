import 'package:flutter_test/flutter_test.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/personal_notes/repository/personal_notes_repository.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_adapter.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tools/calendar/ulits/calendar_cubit.dart';
import 'package:otzaria/utils/book_open_coordinator.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';

class _MockHistoryBloc extends Mock implements HistoryBloc {}

class _MockTabsBloc extends Mock implements TabsBloc {}

class _MockNavigationBloc extends Mock implements NavigationBloc {}

class _StubCalendarCubit extends Mock implements CalendarCubit {
  _StubCalendarCubit(this.currentState);

  CalendarState currentState;

  @override
  CalendarState get state => currentState;
}

class _MockWorkspaceBloc extends Mock implements WorkspaceBloc {}

class _MockSearchRepository extends Mock implements SearchRepository {}

class _MockPersonalNotesRepository extends Mock
    implements PersonalNotesRepository {}

class _MockBookOpenCoordinator extends Mock implements BookOpenCoordinator {}

class _MockPluginRegistryRepository extends Mock
    implements PluginRegistryRepository {}

void main() {
  group('PluginBridgeAdapter.getJewishDate', () {
    late _StubCalendarCubit calendarCubit;
    late PluginBridgeAdapter adapter;

    setUp(() {
      calendarCubit = _StubCalendarCubit(
        _buildCalendarState(DateTime(2026, 1, 1), inIsrael: true),
      );
      adapter = PluginBridgeAdapter(
        InstalledPlugin(
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
            permissions: const ['calendar.read'],
            networkEnabled: false,
            networkAllowlist: const [],
            toolTabTitle: 'Test Plugin',
            toolTabOrder: 1,
            defaultPinned: true,
            publishedDataTypes: const [],
          ),
          installedAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        dependencies: PluginBridgeDependencies(
          historyBloc: _MockHistoryBloc(),
          tabsBloc: _MockTabsBloc(),
          navigationBloc: _MockNavigationBloc(),
          calendarCubit: calendarCubit,
          workspaceBloc: _MockWorkspaceBloc(),
          searchRepository: _MockSearchRepository(),
          personalNotesRepository: _MockPersonalNotesRepository(),
          bookOpenCoordinator: _MockBookOpenCoordinator(),
          themePayloadBuilder: () => <String, dynamic>{},
          showConfirmDialog: ({required title, required content}) async => true,
          showWarningDialog: ({
            required title,
            required content,
            required subtitle,
          }) async =>
              true,
        ),
        pluginRepository: _MockPluginRegistryRepository(),
      );
    });

    test('returns extended jewish date fields for yom tov dates', () async {
      final jewishDate = JewishDate()
        ..setJewishDate(5786, JewishDate.NISSAN, 15);
      final gregorianDate = jewishDate.getGregorianCalendar();
      final state = _buildCalendarState(gregorianDate, inIsrael: true);
      final formatter = HebrewDateFormatter()..hebrewFormat = true;
      final jewishCalendar = JewishCalendar.fromDateTime(gregorianDate)
        ..inIsrael = true;

      calendarCubit.currentState = state;

      final response = await adapter.execute('calendar', 'getJewishDate', {})
          as Map<String, dynamic>;

      expect(response['year'], jewishCalendar.getJewishYear());
      expect(response['month'], jewishCalendar.getJewishMonth());
      expect(response['day'], jewishCalendar.getJewishDayOfMonth());
      expect(response['monthName'], formatter.formatMonth(jewishCalendar));
      expect(response['isLeapYear'], jewishCalendar.isJewishLeapYear());
      expect(response['isShabbat'], jewishCalendar.getDayOfWeek() == 7);

      final holidays =
          (response['holidays'] as List<dynamic>).cast<Map<String, String>>();
      expect(
        holidays,
        contains(
          allOf(
            containsPair('kind', 'yomTov'),
            containsPair('text', formatter.formatYomTov(jewishCalendar)),
          ),
        ),
      );
    });

    test('returns rosh chodesh entries with correct kind', () async {
      final jewishDate = JewishDate()
        ..setJewishDate(5786, JewishDate.NISSAN, 1);
      final gregorianDate = jewishDate.getGregorianCalendar();
      final state = _buildCalendarState(gregorianDate, inIsrael: true);
      final formatter = HebrewDateFormatter()..hebrewFormat = true;
      final jewishCalendar = JewishCalendar.fromDateTime(gregorianDate)
        ..inIsrael = true;

      calendarCubit.currentState = state;

      final response = await adapter.execute('calendar', 'getJewishDate', {})
          as Map<String, dynamic>;
      final holidays =
          (response['holidays'] as List<dynamic>).cast<Map<String, String>>();

      expect(
        holidays,
        contains(
          allOf(
            containsPair('kind', 'roshChodesh'),
            containsPair('text', formatter.formatRoshChodesh(jewishCalendar)),
          ),
        ),
      );
    });
  });
}

CalendarState _buildCalendarState(
  DateTime gregorianDate, {
  required bool inIsrael,
}) {
  final jewishDate = JewishDate.fromDateTime(gregorianDate);
  return CalendarState(
    selectedJewishDate: jewishDate,
    selectedGregorianDate: gregorianDate,
    selectedCity: 'ירושלים',
    dailyTimes: const {},
    currentJewishDate: jewishDate,
    currentGregorianDate: gregorianDate,
    calendarType: CalendarType.combined,
    calendarView: CalendarView.month,
    inIsrael: inIsrael,
  );
}
