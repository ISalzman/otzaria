import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kosher_dart/kosher_dart.dart';
import 'package:mockito/mockito.dart';
import 'package:otzaria/data/data_providers/book_composite_key.dart';
import 'package:otzaria/data/data_providers/library_provider.dart';
import 'package:otzaria/data/data_providers/library_provider_manager.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/navigation/bloc/navigation_bloc.dart';
import 'package:otzaria/personal_notes/repository/personal_notes_repository.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_adapter.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/models/plugin_permission_grant.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/services/plugin_network_fetch_service.dart';
import 'package:otzaria/search/search_repository.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/tools/calendar/utils/calendar_cubit.dart';
import 'package:otzaria/utils/navigation/book_open_coordinator.dart';
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
  bool? permissionGrant;

  @override
  Future<List<PluginPermissionGrant>> getPluginPermissions(
      String pluginId) async {
    return permissions;
  }

  @override
  Future<bool?> getPermission(String pluginId, String permission) async {
    return permissionGrant;
  }
}

InstalledPlugin _buildInstalledPlugin({
  List<String> permissions = const [],
  bool networkEnabled = false,
  List<String> networkAllowlist = const [],
}) {
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
      networkEnabled: networkEnabled,
      networkAllowlist: networkAllowlist,
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

  group('PluginBridgeAdapter.library.getBookContent', () {
    late PluginBridgeAdapter adapter;
    late _FakeBookProvider fakeProvider;

    setUp(() {
      // 1. הזרקת ספריית קטלוג מותאמת: TextBook עם fileType='docx' (מקרה הבאג),
      //    TextBook עם fileType='txt' (לוודא שגם הדרך הרגילה עובדת), ו-PdfBook
      //    שצריך לפול-בק (כי הוא לא TextBook).
      final textBookDocx = TextBook(
        title: 'ספר-docx',
        categoryId: 100,
        fileType: 'docx',
      );
      final textBookTxt = TextBook(
        title: 'ספר-txt',
        categoryId: 200,
        fileType: 'txt',
      );
      final pdfBookEntry = PdfBook(
        title: 'ספר-pdf',
        path: '/tmp/pdf.pdf',
        categoryId: 300,
        fileType: 'pdf',
      );

      final library = Library(categories: [
        Category(
          title: 'בדיקה',
          description: '',
          shortDescription: '',
          order: 0,
          subCategories: const [],
          books: [textBookDocx, textBookTxt, pdfBookEntry],
          parent: null,
        ),
      ]);
      DataRepository.instance.library = Future.value(library);

      // 2. תוספי תוכן ל-LibraryProviderManager: נשים מיפויים שמדמים מצב של
      //    משתמש עם seforim.db בלבד (אין קבצי טקסט נפרדים בדיסק). הבאג היה
      //    ש-DataRepository.getBookText ניגש עם fileType='txt' כברירת מחדל
      //    גם כשה-TextBook הוא docx.
      final docxKey = BookCompositeKey.create(
        title: 'ספר-docx',
        categoryId: 100,
        fileType: 'docx',
      );
      final docxFakeTxtKey = BookCompositeKey.create(
        title: 'ספר-docx',
        categoryId: 100,
        fileType: 'txt',
      );
      final txtKey = BookCompositeKey.create(
        title: 'ספר-txt',
        categoryId: 200,
        fileType: 'txt',
      );
      final pdfFallbackKey = BookCompositeKey.create(
        title: 'ספר-pdf',
        categoryId: 300,
        fileType: 'txt',
      );
      final loneTxtKey = BookCompositeKey.create(
        title: 'שלא-בקטלוג',
        categoryId: 999,
        fileType: 'txt',
      );
      final sliceableKey = BookCompositeKey.create(
        title: 'ספר-לחיתוך',
        categoryId: 400,
        fileType: 'txt',
      );

      fakeProvider = _FakeBookProvider({
        docxKey: 'תוכן docx של הספר - נכון',
        docxFakeTxtKey: 'תוכן TXT שגוי - לא היה צריך להגיע לכאן עבור ספר-docx',
        txtKey: 'תוכן txt רגיל',
        pdfFallbackKey: 'תוכן fallback של ה-pdf',
        loneTxtKey: 'תוכן fallback של ספר שאינו בקטלוג',
        sliceableKey: 'ABCDEFGHIJKLMNOP',
      });

      LibraryProviderManager.instance.seedMappingsForTesting(
        mapping: {
          docxKey: fakeProvider,
          docxFakeTxtKey: fakeProvider,
          txtKey: fakeProvider,
          pdfFallbackKey: fakeProvider,
          loneTxtKey: fakeProvider,
          sliceableKey: fakeProvider,
        },
        providers: [fakeProvider],
      );

      adapter = PluginBridgeAdapter(
        _buildInstalledPlugin(permissions: const ['library.read']),
        dependencies: PluginBridgeDependencies(
          historyBloc: _MockHistoryBloc(),
          tabsBloc: _StubTabsBloc(),
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
        pluginRepository: _StubPluginRegistryRepository(),
      );
    });

    tearDown(() {
      LibraryProviderManager.instance.resetForTesting();
    });

    test('זורק כש-bookId חסר', () async {
      expect(
        () => adapter.execute('library', 'getBookContent', const {}),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'TextBook עם fileType=docx מנותב דרך TextBookRepository עם ה-fileType '
        'הנכון (תיקון d94133731)', () async {
      // הבאג: הקוד הישן קרא ל-DataRepository.getBookText שמשתמש ב-fileType=
      // 'txt' כברירת מחדל. עבור משתמש עם seforim.db בלבד, זה היה מחזיר
      // נתון שגוי (או תוכן txt שאינו קיים, או כשל). התיקון: שימוש ב-
      // TextBookRepository שלוקח את ה-fileType מ-metadata של ה-TextBook.
      final result = await adapter
          .execute('library', 'getBookContent', const {'bookId': 'ספר-docx'});

      expect(result, 'תוכן docx של הספר - נכון');
      expect(result, isNot(contains('שגוי')),
          reason: 'אסור שהקוד יפול חזרה ל-fileType=txt לספר docx');
    });

    test('TextBook עם fileType=txt עובר דרך TextBookRepository כרגיל',
        () async {
      final result = await adapter
          .execute('library', 'getBookContent', const {'bookId': 'ספר-txt'});

      expect(result, 'תוכן txt רגיל');
    });

    test(
        'ספר שאינו בקטלוג נופל ל-DataRepository.getBookText (ברירת המחדל '
        'fileType=txt)', () async {
      final result = await adapter
          .execute('library', 'getBookContent', const {'bookId': 'שלא-בקטלוג'});

      expect(result, 'תוכן fallback של ספר שאינו בקטלוג');
    });

    test('PdfBook בקטלוג (לא TextBook) נופל ל-DataRepository.getBookText',
        () async {
      // ה-discriminator הוא `cataloged is TextBook`. PdfBook נכשל בבדיקה
      // ולכן נכנס לענף ה-else במקום ל-TextBookRepository.
      final result = await adapter
          .execute('library', 'getBookContent', const {'bookId': 'ספר-pdf'});

      expect(result, 'תוכן fallback של ה-pdf');
    });

    test('title כ-alias ל-bookId נתמך (תאימות לאחור)', () async {
      final result = await adapter
          .execute('library', 'getBookContent', const {'title': 'ספר-txt'});

      expect(result, 'תוכן txt רגיל');
    });

    test('offset חותך מתחילת הטקסט כשלא ניתן section', () async {
      // טקסט "ABCDEFGHIJKLMNOP" באורך 16, offset=4 — מתחיל מ-'E'.
      final result = await adapter.execute('library', 'getBookContent',
          const {'bookId': 'ספר-לחיתוך', 'offset': 4, 'limit': 5});

      expect(result, 'EFGHI');
    });

    test('limit שולט בגודל המקטע המוחזר', () async {
      final result = await adapter.execute('library', 'getBookContent',
          const {'bookId': 'ספר-לחיתוך', 'limit': 3});

      expect(result, 'ABC');
    });

    test(
        'section + offset: ה-offset נספר יחסית למיקום ה-section, לא לתחילת '
        'הטקסט (תיקון 00ccfa63d)', () async {
      // טקסט "ABCDEFGHIJKLMNOP". section='C' נמצא ב-index 2.
      // offset=3 פירושו 3 תווים אחרי 'C', כלומר מתחילים מ-index 5 ('F').
      // הקוד הישן התעלם מה-offset כש-section ניתן (startIndex = idx בלבד).
      final result = await adapter.execute(
        'library',
        'getBookContent',
        const {
          'bookId': 'ספר-לחיתוך',
          'section': 'C',
          'offset': 3,
          'limit': 4,
        },
      );

      expect(result, 'FGHI',
          reason: 'section ב-index 2 + offset 3 → התחלה ב-index 5');
    });

    test('section ב-offset=0 מתחיל מהמיקום של section (התנהגות שלא השתנתה)',
        () async {
      final result = await adapter.execute(
        'library',
        'getBookContent',
        const {
          'bookId': 'ספר-לחיתוך',
          'section': 'D',
          'offset': 0,
          'limit': 3,
        },
      );

      expect(result, 'DEF');
    });

    test('section שלא נמצא מתעלם וחוזר ל-offset רגיל מתחילת הטקסט', () async {
      final result = await adapter.execute(
        'library',
        'getBookContent',
        const {
          'bookId': 'ספר-לחיתוך',
          'section': 'XYZ',
          'offset': 2,
          'limit': 3,
        },
      );

      expect(result, 'CDE',
          reason: 'section שלא נמצא → startIndex נשאר offset (2)');
    });

    test('limit > 5000 חתוך ל-5000', () async {
      // לוקחים תוכן קצר ולכן באמת הקליפ יהיה אורך הטקסט.
      final result = await adapter.execute('library', 'getBookContent',
          const {'bookId': 'ספר-לחיתוך', 'limit': 99999});

      // limit מקבוע ל-5000, end = (0 + 5000).clamp(0, 16) = 16 → כל הטקסט
      expect(result, 'ABCDEFGHIJKLMNOP');
    });

    test('offset החורג מהאורך מקובע לסוף הטקסט (clamp)', () async {
      final result = await adapter.execute('library', 'getBookContent',
          const {'bookId': 'ספר-לחיתוך', 'offset': 999, 'limit': 5});

      expect(result, '');
    });
  });

  group('PluginBridgeAdapter.library.getTree', () {
    late PluginBridgeAdapter adapter;

    setUp(() {
      // עץ דו-שכבתי: תנך -> {ספר בראשית טקסט} ו-ראשונים -> {רשי PDF}.
      final genesis = TextBook(title: 'בראשית', categoryId: 1, fileType: 'txt')
        ..author = 'משה רבנו'
        ..topics = 'תורה';
      final rashi = PdfBook(
        title: 'רשי',
        path: '/tmp/rashi.pdf',
        categoryId: 2,
        fileType: 'pdf',
      );

      final tanach = Category(
        title: 'תנך',
        description: '',
        shortDescription: '',
        order: 0,
        subCategories: [],
        books: [genesis],
        parent: null,
      );
      final rishonim = Category(
        title: 'ראשונים',
        description: '',
        shortDescription: '',
        order: 1,
        subCategories: const [],
        books: [rashi],
        parent: tanach,
      );
      tanach.subCategories.add(rishonim);

      final library = Library(categories: [tanach]);
      // קישור parent של הקטגוריה העליונה לספרייה (כפי שנבנה בקטלוג האמיתי)
      // כדי שחישוב ה-path יעבוד נכון.
      tanach.parent = library;
      DataRepository.instance.library = Future.value(library);

      adapter = PluginBridgeAdapter(
        _buildInstalledPlugin(permissions: const ['library.books.read']),
        dependencies: PluginBridgeDependencies(
          historyBloc: _MockHistoryBloc(),
          tabsBloc: _StubTabsBloc(),
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
        pluginRepository: _StubPluginRegistryRepository(),
      );
    });

    test('מחזיר את העץ המלא עם קטגוריות מקוננות וספרים', () async {
      final result = await adapter.execute('library', 'getTree', const {})
          as Map<String, dynamic>;

      expect(result['title'], 'ספריית אוצריא');
      expect(result['path'], '/');
      final topCategories = result['categories'] as List<dynamic>;
      expect(topCategories, hasLength(1));

      final tanach = topCategories.first as Map<String, dynamic>;
      expect(tanach['title'], 'תנך');
      expect(tanach['path'], '/תנך');

      final tanachBooks = tanach['books'] as List<dynamic>;
      expect(tanachBooks, hasLength(1));
      final genesis = tanachBooks.first as Map<String, dynamic>;
      expect(genesis['bookId'], 'בראשית');
      expect(genesis['type'], 'text');
      expect(genesis['author'], 'משה רבנו');
      expect(genesis['topics'], 'תורה');

      final subCategories = tanach['categories'] as List<dynamic>;
      expect(subCategories, hasLength(1));
      final rishonim = subCategories.first as Map<String, dynamic>;
      expect(rishonim['title'], 'ראשונים');
      final rashi =
          (rishonim['books'] as List<dynamic>).first as Map<String, dynamic>;
      expect(rashi['type'], 'pdf');
    });

    test('path מצמצם את העץ לתת-קטגוריה', () async {
      final result = await adapter
              .execute('library', 'getTree', const {'path': '/תנך/ראשונים'})
          as Map<String, dynamic>;

      expect(result['title'], 'ראשונים');
      final books = result['books'] as List<dynamic>;
      expect((books.first as Map<String, dynamic>)['title'], 'רשי');
    });

    test('path שאינו קיים מחזיר null', () async {
      final result = await adapter
          .execute('library', 'getTree', const {'path': '/לא-קיים'});

      expect(result, isNull);
    });

    test('includeBooks=false משמיט את רשימות הספרים', () async {
      final result = await adapter
              .execute('library', 'getTree', const {'includeBooks': false})
          as Map<String, dynamic>;

      expect(result.containsKey('books'), isFalse);
      final tanach =
          (result['categories'] as List<dynamic>).first as Map<String, dynamic>;
      expect(tanach.containsKey('books'), isFalse);
      expect(tanach['title'], 'תנך');
    });
  });

  group('PluginBridgeAdapter.network', () {
    late _StubPluginRegistryRepository pluginRegistryRepository;
    late PluginBridgeAdapter adapter;

    setUp(() {
      pluginRegistryRepository = _StubPluginRegistryRepository()
        ..permissionGrant = true;

      adapter = PluginBridgeAdapter(
        _buildInstalledPlugin(
          permissions: const ['network.access'],
          networkEnabled: true,
          networkAllowlist: const [],
        ),
        dependencies: PluginBridgeDependencies(
          historyBloc: _MockHistoryBloc(),
          tabsBloc: _StubTabsBloc(),
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

    test('network.fetch חוסם גם URL מובנה אם המניפסט של התוסף לא הצהיר עליו',
        () async {
      await expectLater(
        () => adapter.execute('network', 'fetch', const {
          'url': 'https://nakdan.dicta.org.il/api',
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('error.forbidden'),
          ),
        ),
      );
    });

    test(
        'network.fetch חסום כשהמניפסט כיבה network.enabled גם אם יש grant ו-allowlist',
        () async {
      final disabledAdapter = PluginBridgeAdapter(
        _buildInstalledPlugin(
          permissions: const ['network.access'],
          networkEnabled: false,
          networkAllowlist: const ['https://nakdan.dicta.org.il/api'],
        ),
        dependencies: PluginBridgeDependencies(
          historyBloc: _MockHistoryBloc(),
          tabsBloc: _StubTabsBloc(),
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

      await expectLater(
        () => disabledAdapter.execute('network', 'fetch', const {
          'url': 'https://nakdan.dicta.org.il/api',
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('network.enabled required'),
          ),
        ),
      );
    });
  });

  group('PluginBridgeAdapter.network.fetch (HTTP contract)', () {
    late _StubPluginRegistryRepository pluginRegistryRepository;

    PluginBridgeAdapter buildAdapter(PluginNetworkFetchService fetchService) {
      return PluginBridgeAdapter(
        _buildInstalledPlugin(
          permissions: const ['network.access'],
          networkEnabled: true,
          networkAllowlist: const ['https://nakdan.dicta.org.il/api'],
        ),
        dependencies: PluginBridgeDependencies(
          historyBloc: _MockHistoryBloc(),
          tabsBloc: _StubTabsBloc(),
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
        networkFetchService: fetchService,
      );
    }

    setUp(() {
      pluginRegistryRepository = _StubPluginRegistryRepository()
        ..permissionGrant = true;
    });

    test('POST מעביר method/headers/body ומחזיר {status, ok, body}', () async {
      late http.Request captured;
      final fetchService = PluginNetworkFetchService(
        client: MockClient((req) async {
          captured = req;
          return http.Response('{"data":[]}', 200);
        }),
      );
      final adapter = buildAdapter(fetchService);

      final result = await adapter.execute('network', 'fetch', const {
        'url': 'https://nakdan.dicta.org.il/api',
        'method': 'POST',
        'headers': {'Content-Type': 'application/json;charset=UTF-8'},
        'body': '{"task":"nakdan"}',
      }) as Map<String, dynamic>;

      expect(captured.method, 'POST');
      expect(captured.body, '{"task":"nakdan"}');
      expect(
          captured.headers['content-type'], 'application/json;charset=UTF-8');
      expect(result['status'], 200);
      expect(result['ok'], isTrue);
      expect(result['body'], '{"data":[]}');
    });

    test('סטטוס שאינו 2xx מוחזר עם ok=false', () async {
      final fetchService = PluginNetworkFetchService(
        client: MockClient((req) async => http.Response('err', 500)),
      );
      final adapter = buildAdapter(fetchService);

      final result = await adapter.execute('network', 'fetch', const {
        'url': 'https://nakdan.dicta.org.il/api',
      }) as Map<String, dynamic>;

      expect(result['status'], 500);
      expect(result['ok'], isFalse);
    });

    test('method לא תקין נדחה לפני ביצוע הבקשה', () async {
      var hit = false;
      final fetchService = PluginNetworkFetchService(
        client: MockClient((req) async {
          hit = true;
          return http.Response('', 200);
        }),
      );
      final adapter = buildAdapter(fetchService);

      await expectLater(
        () => adapter.execute('network', 'fetch', const {
          'url': 'https://nakdan.dicta.org.il/api',
          'method': 'POST DELETE',
        }),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('invalid method'),
        )),
      );
      expect(hit, isFalse);
    });
  });
}

/// Provider פיקטיבי שמחזיר טקסט לפי מפתחות מוגדרים מראש.
/// משמש לבדיקת ה-routing דרך LibraryProviderManager בלי לגשת ל-DB אמיתי.
class _FakeBookProvider implements LibraryProvider {
  final Map<BookCompositeKey, String> _bookTextByKey;

  _FakeBookProvider(this._bookTextByKey);

  @override
  String get providerId => 'fake';

  @override
  String get displayName => 'Fake';

  @override
  String get sourceIndicator => 'F';

  @override
  int get priority => 1;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<Map<String, List<Book>>> loadBooks(
      Map<String, Map<String, dynamic>> metadata) async {
    return const {};
  }

  @override
  Future<bool> hasBook(String title, int categoryId, String fileType) async {
    final key = BookCompositeKey.create(
      title: title,
      categoryId: categoryId,
      fileType: fileType,
    );
    return _bookTextByKey.containsKey(key);
  }

  @override
  Future<String?> getBookText(
    String title,
    int categoryId,
    String fileType, {
    bool preferUserBooks = false,
  }) async {
    final key = BookCompositeKey.create(
      title: title,
      categoryId: categoryId,
      fileType: fileType,
    );
    return _bookTextByKey[key];
  }

  @override
  Future<List<TocEntry>?> getBookToc(
    String title,
    int categoryId,
    String fileType, {
    bool preferUserBooks = false,
  }) async {
    return null;
  }

  @override
  Future<Set<String>> getAvailableBookTitles() async {
    return _bookTextByKey.keys.map((k) => k.toStorageKey()).toSet();
  }

  @override
  Future<Library> buildLibraryCatalog(
    Map<String, Map<String, dynamic>> metadata,
    String rootPath,
  ) async {
    return Library(categories: const []);
  }

  @override
  Future<List<Link>> getAllLinksForBook(
      String title, int categoryId, String fileType) async {
    return const [];
  }

  @override
  Future<String> getLinkContent(Link link) async {
    return '';
  }
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
    todayGregorianDate: gregorianDate,
    calendarType: CalendarType.combined,
    calendarView: CalendarView.month,
    dayTransition: CalendarDayTransition.sunset,
    inIsrael: inIsrael,
  );
}
