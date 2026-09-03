import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/view/toc_navigator_screen.dart';
import 'package:otzaria/widgets/lists/nav_tree_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// דיבורי-המתחיל בעץ הניווט: מוצגים כתתי-כותרות, אך "הכותרת הנוכחית"
/// נשארת ברמת הכותרות ו-`tableOfContents` שבמצב אינו משתנה.
class _TestTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _TestTextBookBloc(super.initialState) {
    on<TextBookEvent>((event, emit) {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TextBookLoaded _loadedState({
  required List<TocEntry> toc,
  required List<int> visibleIndices,
}) {
  return TextBookLoaded(
    book: TextBook(title: 'ספר בדיקה'),
    showLeftPane: true,
    content: List.generate(10, (i) => 'שורה $i'),
    fontSize: 18,
    showSplitView: false,
    activeCommentators: const [],
    commentatorGroups: const [],
    availableCommentators: const [],
    links: const [],
    visibleLinks: const [],
    linksByLine: const {},
    tableOfContents: toc,
    removeNikud: false,
    visibleIndices: visibleIndices,
    selectedIndex: null,
    pinLeftPane: false,
    searchText: '',
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );
}

Future<TextBookBloc> _pumpViewer(
  WidgetTester tester, {
  required List<TocEntry> toc,
  required Map<int, String> dibburim,
  required List<int> visibleIndices,
}) async {
  final bloc = _TestTextBookBloc(
    _loadedState(toc: toc, visibleIndices: visibleIndices),
  );
  addTearDown(bloc.close);
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BlocProvider<TextBookBloc>.value(
            value: bloc,
            child: SizedBox(
              width: 400,
              height: 800,
              child: TocViewer(
                scrollController: ItemScrollController(),
                closeLeftPaneCallback: () {},
                focusNode: focusNode,
                loadDibburim: (_) async => dibburim,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

bool _isSelected(WidgetTester tester, String title) => tester
    .widget<NavTreeTile>(
      find.byWidgetPredicate((w) => w is NavTreeTile && w.title == title),
    )
    .isSelected;

void main() {
  testWidgets('דיבורי-המתחיל מוצגים תחת הכותרת שלפניהם', (tester) async {
    final toc = [
      TocEntry(text: 'פרק א', index: 0, level: 1),
      TocEntry(text: 'פרק ב', index: 5, level: 1),
    ];
    await _pumpViewer(
      tester,
      toc: toc,
      dibburim: {2: 'ד"ה ראשון', 7: 'ד"ה שני'},
      visibleIndices: const [0],
    );

    // כותרות רמה 1 פתוחות כברירת מחדל, ולכן הדיבורים גלויים.
    expect(find.text('ד"ה ראשון'), findsOneWidget);
    expect(find.text('ד"ה שני'), findsOneWidget);
    // העץ שבמצב לא נגע: הדיבורים חיים רק בעותק המוצג.
    expect(toc[0].children, isEmpty);
    expect(toc[1].children, isEmpty);
  });

  testWidgets('הכותרת הנוכחית נשארת ברמת הכותרת גם כשקוראים בתוך דיבור', (
    tester,
  ) async {
    final toc = [
      TocEntry(text: 'פרק א', index: 0, level: 1),
      TocEntry(text: 'פרק ב', index: 5, level: 1),
    ];
    await _pumpViewer(
      tester,
      toc: toc,
      dibburim: {2: 'ד"ה ראשון', 3: 'ד"ה שני'},
      // השורה הנראית היא של "ד"ה שני".
      visibleIndices: const [3],
    );

    expect(_isSelected(tester, 'פרק א'), isTrue);
    expect(_isSelected(tester, 'ד"ה ראשון'), isFalse);
    expect(_isSelected(tester, 'ד"ה שני'), isFalse);
  });

  testWidgets('בלי דיבורים (מסד ישן) העץ נשאר כפי שהוא', (tester) async {
    final toc = [TocEntry(text: 'פרק א', index: 0, level: 1)];
    await _pumpViewer(
      tester,
      toc: toc,
      dibburim: const {},
      visibleIndices: const [0],
    );

    expect(find.text('פרק א'), findsOneWidget);
    expect(find.byType(NavTreeTile), findsOneWidget);
  });
}
