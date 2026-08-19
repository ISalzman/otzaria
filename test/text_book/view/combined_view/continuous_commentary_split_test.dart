import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_bloc.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_event.dart';
import 'package:otzaria/personal_notes/bloc/personal_notes_state.dart';
import 'package:otzaria/settings/engine/settings_bloc.dart';
import 'package:otzaria/settings/engine/settings_event.dart';
import 'package:otzaria/settings/engine/settings_state.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/utils/reading_segments.dart';
import 'package:otzaria/text_book/view/combined_view/combined_book_screen.dart';
import 'package:otzaria/text_book/view/widgets/continuous_reading_paragraph.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../test_helpers/memory_cache_provider.dart';

// issue #875 — במצב קריאה רציפה כרטיס המפרשים נבנה בתחתית הפסקה הממוזגת
// כולה (מסכים שלמים מתחת לשורה שנלחצה). התיקון: פיצול רינדור הפסקה סביב
// השורה הנבחרת כך שהכרטיס מופיע מיד מתחתיה.

const _content = ['שורה ראשונה', 'שורה שניה', 'שורה שלישית'];

final _rashiLink = Link(
  heRef: 'רש"י על בראשית א',
  index1: 2,
  path2: 'commentary/רש"י.txt',
  index2: 7,
  connectionType: 'COMMENTARY',
);

TextBookLoaded _continuousState({
  int? selectedIndex,
  Map<int, List<Link>>? linksByLine,
}) {
  return TextBookLoaded(
    book: TextBook(title: 'ספר בדיקה'),
    showLeftPane: false,
    content: _content,
    fontSize: 18,
    showSplitView: false,
    showPageShapeView: false,
    activeCommentators: const ['רש"י'],
    commentatorGroups: const [],
    availableCommentators: const [],
    links: const [],
    visibleLinks: const [],
    linksByLine:
        linksByLine ??
        {
          2: [_rashiLink],
        },
    tableOfContents: const [],
    removeNikud: false,
    visibleIndices: const [0, 1, 2],
    selectedIndex: selectedIndex,
    selectedIndices: selectedIndex == null ? const {} : {selectedIndex},
    pinLeftPane: false,
    searchText: '',
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
    continuousReadingMode: true,
    readingSegments: buildReadingSegments(_content, continuous: true),
  );
}

Future<void> _pumpContinuousView(
  WidgetTester tester,
  TextBookLoaded state,
) async {
  final textBookBloc = _TestTextBookBloc(state);
  final personalNotesBloc = _TestPersonalNotesBloc(
    const PersonalNotesState.initial(),
  );
  final settingsBloc = _TestSettingsBloc(SettingsState.initial());
  final tab = TextBookTab(book: TextBook(title: 'ספר בדיקה'), index: 0);
  addTearDown(textBookBloc.close);
  addTearDown(personalNotesBloc.close);
  addTearDown(settingsBloc.close);
  addTearDown(tab.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<TextBookBloc>.value(value: textBookBloc),
          BlocProvider<PersonalNotesBloc>.value(value: personalNotesBloc),
          BlocProvider<SettingsBloc>.value(value: settingsBloc),
        ],
        child: Scaffold(
          body: CombinedView(
            data: _content,
            openBookCallback: (_) {},
            openLeftPaneTab: (_, {searchText}) {},
            textSize: 18,
            showCommentaryAsExpansionTiles: true,
            tab: tab,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

List<List<int>> _paragraphLineIndices(WidgetTester tester) => tester
    .widgetList<ContinuousReadingParagraph>(
      find.byType(ContinuousReadingParagraph),
    )
    .map(
      (paragraph) => paragraph.lines.map((line) => line.lineIndex).toList(),
    )
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  testWidgets('בחירת שורה באמצע פסקה — הפסקה מפוצלת והכרטיס מתחת לשורה', (
    tester,
  ) async {
    await _pumpContinuousView(tester, _continuousState(selectedIndex: 1));

    expect(
      _paragraphLineIndices(tester),
      [
        [0, 1],
        [2],
      ],
    );
    expect(find.byKey(const ValueKey('commentary_card_1')), findsOneWidget);
  });

  testWidgets('ללא בחירה — פסקה אחת שלמה ובלי כרטיס מפרשים', (tester) async {
    await _pumpContinuousView(tester, _continuousState(selectedIndex: null));

    expect(_paragraphLineIndices(tester), [
      [0, 1, 2],
    ]);
    expect(find.byKey(const ValueKey('commentary_card_1')), findsNothing);
  });

  testWidgets('שורה נבחרת בלי מפרשים — אין פיצול ואין כרטיס', (tester) async {
    await _pumpContinuousView(
      tester,
      _continuousState(selectedIndex: 1, linksByLine: const {}),
    );

    expect(_paragraphLineIndices(tester), [
      [0, 1, 2],
    ]);
    expect(find.byKey(const ValueKey('commentary_card_1')), findsNothing);
  });

  testWidgets('השורה האחרונה נבחרת — הכרטיס בסוף הפסקה בלי חלק שני ריק', (
    tester,
  ) async {
    await _pumpContinuousView(
      tester,
      _continuousState(
        selectedIndex: 2,
        linksByLine: {
          3: [_rashiLink],
        },
      ),
    );

    expect(_paragraphLineIndices(tester), [
      [0, 1, 2],
    ]);
    expect(find.byKey(const ValueKey('commentary_card_2')), findsOneWidget);
  });
}

class _TestTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TestTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPersonalNotesBloc
    extends Bloc<PersonalNotesEvent, PersonalNotesState>
    implements PersonalNotesBloc {
  _TestPersonalNotesBloc(super.initialState) {
    on<PersonalNotesEvent>((event, emit) {});
  }

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
