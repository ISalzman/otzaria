import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/pdf_book/pdf_commentary_panel.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import '../helpers/memory_settings_cache.dart';

// ─── fakes ───────────────────────────────────────────────────────────────────

class _FakeSettingsBloc extends Bloc<SettingsEvent, SettingsState>
    implements SettingsBloc {
  _FakeSettingsBloc() : super(SettingsState.initial()) {
    on<SettingsEvent>((_, __) {});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakePersonalNotesBloc
    extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _FakePersonalNotesBloc()
      : super(const PersonalNotesState(
          isLoading: false,
          bookId: '',
          locatedNotes: [],
          missingNotes: [],
          errorMessage: null,
          filteredLocatedNotes: [],
          filteredMissingNotes: [],
        )) {
    on<PersonalNotesEvent>((_, __) {});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ─── helpers ─────────────────────────────────────────────────────────────────

PdfBook _book() => PdfBook(title: 'מכות', path: '/books/מכות.pdf');

PdfBookTab _tab({
  int? currentLine,
  int? currentLineEnd,
  List<Link> links = const [],
}) {
  final tab = PdfBookTab(book: _book(), pageNumber: 1);
  tab.currentTextLineNumber = currentLine;
  tab.currentTextLineNumberEnd = currentLineEnd;
  tab.links = List.of(links);
  return tab;
}

Link _commentaryLink({required int index1}) => Link(
      heRef: 'רש"י',
      index1: index1,
      path2: '/books/rashi.txt',
      index2: 0,
      connectionType: 'COMMENTARY',
    );

Link _regularLink({required int index1}) => Link(
      heRef: 'פרשה א',
      index1: index1,
      path2: '/books/other.txt',
      index2: 0,
      connectionType: 'NONE',
    );

Widget _wrap(Widget child) => MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>.value(value: _FakeSettingsBloc()),
          BlocProvider<PersonalNotesBloc>.value(
              value: _FakePersonalNotesBloc()),
        ],
        child: Scaffold(body: child),
      ),
    );

PdfCommentaryPanel _panel(
  PdfBookTab tab, {
  bool linksLoading = false,
  int? initialTabIndex,
}) =>
    PdfCommentaryPanel(
      tab: tab,
      linksCount: tab.links.length,
      linksLoading: linksLoading,
      openBookCallback: (_) {},
      fontSize: 16.0,
      initialTabIndex: initialTabIndex,
    );

// ─── tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  // ── לשונית קישורים ──────────────────────────────────────────────────────

  group('PdfCommentaryPanel - לשונית קישורים', () {
    testWidgets(
        'linksLoading=true עם currentTextLineNumber מוגדר → מציג "טוען קישורים..."',
        (tester) async {
      final tab = _tab(currentLine: 10, links: []);

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: true, initialTabIndex: 1)));
      await tester.pump();

      expect(find.text('טוען קישורים...'), findsOneWidget);
      expect(find.text('לא נמצאו קישורים לדף זה'), findsNothing);
    });

    testWidgets(
        'linksLoading=false עם links ריקות → מציג "לא נמצאו קישורים לדף זה"',
        (tester) async {
      final tab = _tab(currentLine: 10, links: []);

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: false, initialTabIndex: 1)));
      await tester.pump();

      expect(find.text('לא נמצאו קישורים לדף זה'), findsOneWidget);
      expect(find.text('טוען קישורים...'), findsNothing);
    });

    testWidgets(
        'linksLoading=true ו-currentTextLineNumber=null → מציג "טוען קישורים..."',
        (tester) async {
      final tab = _tab(links: []); // currentLine=null

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: true, initialTabIndex: 1)));
      await tester.pump();

      expect(find.text('טוען קישורים...'), findsOneWidget);
    });

    testWidgets(
        'קישור מחוץ לטווח (index1 > currentTextLineNumberEnd) לא מוצג',
        (tester) async {
      final tab = _tab(
        currentLine: 10,
        currentLineEnd: 15,
        links: [_regularLink(index1: 16)], // מחוץ לטווח
      );

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: false, initialTabIndex: 1)));
      await tester.pump();

      // אין קישורים בטווח → "לא נמצאו"
      expect(find.text('לא נמצאו קישורים לדף זה'), findsOneWidget);
    });

    testWidgets(
        'currentTextLineNumberEnd=null → fallback לטווח +50, קישור ב-index1=59 נכלל',
        (tester) async {
      final tab = _tab(
        currentLine: 10,
        // currentLineEnd=null → endLine = 10+50 = 60
        links: [_regularLink(index1: 59)],
      );

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: false, initialTabIndex: 1)));
      await tester.pump();

      // קישור בטווח → לא מוצגת הודעת "לא נמצאו"
      expect(find.text('לא נמצאו קישורים לדף זה'), findsNothing);
    });

    testWidgets(
        'currentTextLineNumberEnd=null → fallback לטווח +50, קישור ב-index1=61 מחוץ לטווח',
        (tester) async {
      final tab = _tab(
        currentLine: 10,
        // currentLineEnd=null → endLine = 10+50 = 60
        links: [_regularLink(index1: 61)],
      );

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: false, initialTabIndex: 1)));
      await tester.pump();

      expect(find.text('לא נמצאו קישורים לדף זה'), findsOneWidget);
    });
  });

  // ── לשונית מפרשים ─────────────────────────────────────────────────────────

  group('PdfCommentaryPanel - לשונית מפרשים', () {
    testWidgets(
        'linksLoading=true עם currentTextLineNumber מוגדר → מציג "טוען מפרשים..."',
        (tester) async {
      final tab = _tab(currentLine: 10, links: []);

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: true, initialTabIndex: 0)));
      await tester.pump();

      expect(find.text('טוען מפרשים...'), findsOneWidget);
      expect(find.textContaining('לא נמצאו מפרשים'), findsNothing);
    });

    testWidgets(
        'linksLoading=false ללא links → מציג "לא נמצאו מפרשים לקטע הנבחר"',
        (tester) async {
      final tab = _tab(currentLine: 10, links: []);

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: false, initialTabIndex: 0)));
      await tester.pump();

      expect(find.text('לא נמצאו מפרשים לקטע הנבחר'), findsOneWidget);
      expect(find.text('טוען מפרשים...'), findsNothing);
    });

    testWidgets(
        'מפרש מחוץ לטווח (index1 > currentTextLineNumberEnd) → לא נמצאו מפרשים',
        (tester) async {
      final tab = _tab(
        currentLine: 10,
        currentLineEnd: 15,
        links: [_commentaryLink(index1: 16)], // מחוץ לטווח
      );

      await tester.pumpWidget(
          _wrap(_panel(tab, linksLoading: false, initialTabIndex: 0)));
      await tester.pump();

      expect(find.textContaining('לא נמצאו מפרשים'), findsOneWidget);
    });
  });
}
