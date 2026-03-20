import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/text_book_repository.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTextBookRepository extends TextBookRepository {
  _FakeTextBookRepository() : super(fileSystem: FileSystemData.instance);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TextBookBloc bloc;
  late TextBook book;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.init();
  });

  setUp(() {
    book = TextBook(title: 'ספר בדיקה');
    bloc = TextBookBloc(
      repository: _FakeTextBookRepository(),
      initialState: TextBookInitial.named(book, 10, true, const []),
      scrollController: ItemScrollController(),
      positionsListener: ItemPositionsListener.create(),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  blocTest<TextBookBloc, TextBookState>(
    'ApplyFullBookContent מחליף preview בתוכן מלא ושומר searchText',
    build: () => bloc,
    seed: () => TextBookLoaded(
      book: book,
      content: const ['שורת preview 1', 'שורת preview 2'],
      fontSize: 20,
      showLeftPane: true,
      showSplitView: false,
      activeCommentators: const [],
      commentatorGroups: const [],
      availableCommentators: const [],
      links: const [],
      linksByLine: const {},
      tableOfContents: const [],
      removeNikud: false,
      visibleIndices: const [10],
      pinLeftPane: false,
      searchText: 'שלום',
      scrollController: ItemScrollController(),
      positionsListener: ItemPositionsListener.create(),
    ),
    act: (bloc) => bloc.add(const ApplyFullBookContent(
      bookTitle: 'ספר בדיקה',
      content: ['שורה מלאה 1', 'שורה מלאה 2', 'שורה מלאה 3'],
    )),
    expect: () => [
      isA<TextBookLoaded>()
          .having((state) => state.content.length, 'content length', 3)
          .having((state) => state.searchText, 'searchText', 'שלום'),
    ],
  );
}
