import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/personal_notes/repository/personal_notes_repository.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_adapter.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_permission_grant.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/tools/calendar/ulits/calendar_cubit.dart';
import 'package:otzaria/utils/book_open_coordinator.dart';
import 'package:otzaria/workspaces/bloc/workspace_bloc.dart';

class _MockHistoryBloc extends Mock implements HistoryBloc {}

class _StubTabsBloc extends Mock implements TabsBloc {
  TabsState currentState = TabsState.initial();

  @override
  TabsState get state => currentState;
}

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

class _StubPluginRegistryRepository extends PluginRegistryRepository {
  List<PluginPermissionGrant> permissions = [];

  @override
  Future<List<PluginPermissionGrant>> getPluginPermissions(
      String pluginId) async {
    return permissions;
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

void main() {
  setUpAll(() async {
    await Settings.init(cacheProvider: _MemoryCacheProvider());
  });

  group('PluginBridgeAdapter.getJewishDate', () {
    late _StubCalendarCubit calendarCubit;
    late _StubTabsBloc tabsBloc;
    late PluginBridgeAdapter adapter;

    setUp(() {
      tabsBloc = _StubTabsBloc();
      calendarCubit = _StubCalendarCubit(
        _buildCalendarState(DateTime(2026, 1, 1), inIsrael: true),
      );
      adapter = PluginBridgeAdapter(
        _buildInstalledPlugin(permissions: const ['calendar.read']),
        dependencies: PluginBridgeDependencies(
          historyBloc: _MockHistoryBloc(),
          tabsBloc: tabsBloc,
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
        pluginRepository: _StubPluginRegistryRepository(),
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

  group('PluginBridgeAdapter runtime snapshots', () {
    late _StubTabsBloc tabsBloc;
    late _StubPluginRegistryRepository pluginRegistryRepository;
    late PluginBridgeAdapter adapter;

    setUp(() {
      tabsBloc = _StubTabsBloc();
      pluginRegistryRepository = _StubPluginRegistryRepository();

      adapter = PluginBridgeAdapter(
        _buildInstalledPlugin(
          permissions: const ['app.info.read', 'reader.open'],
        ),
        dependencies: PluginBridgeDependencies(
          historyBloc: _MockHistoryBloc(),
          tabsBloc: tabsBloc,
          navigationBloc: _MockNavigationBloc(),
          calendarCubit: _StubCalendarCubit(
            _buildCalendarState(DateTime(2026, 1, 1), inIsrael: true),
          ),
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
        pluginRepository: pluginRegistryRepository,
      );
    });

    test('app.getGrantedPermissions returns only granted permissions',
        () async {
      pluginRegistryRepository.permissions = [
        PluginPermissionGrant(
          pluginId: 'test.plugin',
          permission: 'reader.open',
          granted: true,
          grantedAt: DateTime(2026, 1, 1),
        ),
        PluginPermissionGrant(
          pluginId: 'test.plugin',
          permission: 'app.info.read',
          granted: true,
          grantedAt: DateTime(2026, 1, 1),
        ),
        PluginPermissionGrant(
          pluginId: 'test.plugin',
          permission: 'notes.write',
          granted: false,
          grantedAt: DateTime(2026, 1, 1),
        ),
      ];

      final response = await adapter.execute('app', 'getGrantedPermissions', {})
          as Map<String, dynamic>;

      expect(response['permissions'], ['app.info.read', 'reader.open']);
    });

    test('reader.getCurrentRef returns current reference for active pdf tab',
        () async {
      final currentTab = PdfBookTab(
        book: PdfBook(title: 'מסילת ישרים', path: '/tmp/mesilat.pdf'),
        pageNumber: 17,
      )..currentTitle.value = 'פרק ב';
      tabsBloc.currentState = TabsState(tabs: [currentTab], currentTabIndex: 0);

      final response = await adapter.execute('reader', 'getCurrentRef', {})
          as Map<String, dynamic>;

      expect(response['currentBook'], 'מסילת ישרים');
      expect(response['currentBookId'], 'מסילת ישרים');
      expect(response['currentIndex'], 17);
      expect(response['currentRef'], 'פרק ב');
    });

    test('reader.getCurrentRef returns null ref for pdf tab without title',
        () async {
      final currentTab = PdfBookTab(
        book: PdfBook(title: 'מסילת ישרים', path: '/tmp/mesilat.pdf'),
        pageNumber: 0,
      );
      tabsBloc.currentState = TabsState(tabs: [currentTab], currentTabIndex: 0);

      final response = await adapter.execute('reader', 'getCurrentRef', {})
          as Map<String, dynamic>;

      expect(response['currentBook'], 'מסילת ישרים');
      expect(response['currentBookId'], 'מסילת ישרים');
      expect(response['currentIndex'], 0);
      expect(response['currentRef'], isNull);
    });

    test('reader.getCurrentRef returns current reference for active text tab',
        () async {
      final currentTab = TextBookTab(
        book: TextBook(title: 'בראשית'),
        index: 42,
      )..currentTitle.value = 'פרק ג';
      tabsBloc.currentState = TabsState(tabs: [currentTab], currentTabIndex: 0);

      final response = await adapter.execute('reader', 'getCurrentRef', {})
          as Map<String, dynamic>;

      expect(response['currentBook'], 'בראשית');
      expect(response['currentBookId'], 'בראשית');
      expect(response['currentIndex'], 42);
      expect(response['currentRef'], 'פרק ג');
    });

    test('reader.getCurrentRef returns null when no tab is active', () async {
      tabsBloc.currentState = TabsState.initial();

      final response = await adapter.execute('reader', 'getCurrentRef', {})
          as Map<String, dynamic>;

      expect(response['currentBook'], isNull);
      expect(response['currentBookId'], isNull);
      expect(response['currentIndex'], 0);
      expect(response['currentRef'], isNull);
    });

    test(
        'reader.getSelection returns current text selection for active text tab',
        () async {
      final currentTab = TextBookTab(
        book: TextBook(title: 'בראשית'),
        index: 42,
      )..currentTitle.value = 'פרק ג';
      currentTab.bloc.emit(
        TextBookLoaded.initial(
          book: currentTab.book,
          index: currentTab.index,
          showLeftPane: false,
          splitView: false,
        ).copyWith(
          visibleIndices: [42],
          currentTitle: 'פרק ג',
          selectedTextForNote: 'ויאמר אלהים',
          selectedTextStart: 120,
          selectedTextEnd: 131,
        ),
      );
      tabsBloc.currentState = TabsState(tabs: [currentTab], currentTabIndex: 0);

      final response = await adapter.execute('reader', 'getSelection', {});

      expect(response, isA<Map<String, dynamic>>());
      final data = response as Map<String, dynamic>;
      expect(data['text'], 'ויאמר אלהים');
      expect(data['start'], 120);
      expect(data['end'], 131);
      expect(data['currentRef'], 'פרק ג');
      expect(data['currentBook'], 'בראשית');
      expect(data['currentBookId'], 'בראשית');
      expect(data['currentIndex'], 42);
    });
  });
}

class _MemoryCacheProvider extends CacheProvider {
  final Map<String, Object?> _values = {};

  @override
  Future<void> init() async {}

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  Set getKeys() => _values.keys.toSet();

  @override
  bool? getBool(String key, {bool? defaultValue}) =>
      _values[key] as bool? ?? defaultValue;

  @override
  double? getDouble(String key, {double? defaultValue}) =>
      _values[key] as double? ?? defaultValue;

  @override
  int? getInt(String key, {int? defaultValue}) =>
      _values[key] as int? ?? defaultValue;

  @override
  String? getString(String key, {String? defaultValue}) =>
      _values[key] as String? ?? defaultValue;

  @override
  T? getValue<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> removeAll() async {
    _values.clear();
  }

  @override
  Future<void> setBool(String key, bool? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(String key, double? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(String key, int? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setObject<T>(String key, T? value) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(String key, String? value) async {
    _values[key] = value;
  }
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
