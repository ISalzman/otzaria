import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/data/data_providers/file_system_data_provider.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/text_book_repository.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../test_helpers/memory_cache_provider.dart';

class _FakeTextBookRepository extends TextBookRepository {
  _FakeTextBookRepository() : super(fileSystem: FileSystemData.instance);
}

/// ההחלפה היזומה בכרטיסיית המפרשים חלה על המפרשים בלבד.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TextBookBloc bloc;
  late TextBook book;

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  setUp(() {
    book = TextBook(title: 'ספר בדיקה');
    bloc = TextBookBloc(
      repository: _FakeTextBookRepository(),
      initialState: TextBookInitial.named(book, 0, true, const []),
      scrollController: ItemScrollController(),
      positionsListener: ItemPositionsListener.create(),
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  TextBookLoaded seed({
    bool removeNikud = false,
    bool nikudExemptByTanach = false,
    bool removePunctuation = false,
    bool punctuationExemptByTanach = false,
  }) => TextBookLoaded(
    book: book,
    content: const ['שורה א'],
    fontSize: 20,
    showLeftPane: true,
    showSplitView: false,
    activeCommentators: const [],
    commentatorGroups: const [],
    availableCommentators: const [],
    links: const [],
    linksByLine: const {},
    tableOfContents: const [],
    isTanach: true,
    removeNikud: removeNikud,
    nikudExemptByTanach: nikudExemptByTanach,
    removePunctuation: removePunctuation,
    punctuationExemptByTanach: punctuationExemptByTanach,
    visibleIndices: const [0],
    pinLeftPane: false,
    searchText: '',
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );

  blocTest<TextBookBloc, TextBookState>(
    'ToggleNikud רגיל אינו מבטל את פטור התנ״ך',
    build: () => bloc,
    seed: () => seed(removeNikud: true, nikudExemptByTanach: true),
    act: (bloc) => bloc.add(const ToggleNikud(false)),
    expect: () => [
      isA<TextBookLoaded>()
          .having((s) => s.removeNikud, 'removeNikud', isFalse)
          .having((s) => s.commentaryRemoveNikud, 'המפרשים', isTrue),
    ],
  );

  blocTest<TextBookBloc, TextBookState>(
    'ToggleNikud עם applyToCommentaries מחזיר ניקוד למפרשים בלבד',
    build: () => bloc,
    seed: () => seed(nikudExemptByTanach: true),
    act: (bloc) =>
        bloc.add(const ToggleNikud(false, applyToCommentaries: true)),
    expect: () => [
      isA<TextBookLoaded>()
          .having((s) => s.removeNikud, 'הספר', isFalse)
          .having((s) => s.nikudExemptByTanach, 'הפטור', isTrue)
          .having(
            (s) => s.commentaryRemoveNikudOverride,
            'עקיפת המפרשים',
            isFalse,
          )
          .having((s) => s.commentaryRemoveNikud, 'המפרשים', isFalse),
    ],
  );

  blocTest<TextBookBloc, TextBookState>(
    'ToggleNikud(true) עם applyToCommentaries מסתיר ניקוד במפרשים בלבד',
    build: () => bloc,
    seed: () => seed(nikudExemptByTanach: true),
    act: (bloc) => bloc.add(const ToggleNikud(true, applyToCommentaries: true)),
    expect: () => [
      isA<TextBookLoaded>()
          .having((s) => s.removeNikud, 'הספר', isFalse)
          .having(
            (s) => s.commentaryRemoveNikudOverride,
            'עקיפת המפרשים',
            isTrue,
          )
          .having((s) => s.commentaryRemoveNikud, 'המפרשים', isTrue),
    ],
  );

  blocTest<TextBookBloc, TextBookState>(
    'TogglePunctuation רגיל אינו מבטל את פטור התנ״ך',
    build: () => bloc,
    seed: () => seed(removePunctuation: true, punctuationExemptByTanach: true),
    act: (bloc) => bloc.add(const TogglePunctuation(false)),
    expect: () => [
      isA<TextBookLoaded>()
          .having((s) => s.removePunctuation, 'removePunctuation', isFalse)
          .having((s) => s.commentaryRemovePunctuation, 'המפרשים', isTrue),
    ],
  );

  blocTest<TextBookBloc, TextBookState>(
    'TogglePunctuation עם applyToCommentaries מחזיר פיסוק למפרשים בלבד',
    build: () => bloc,
    seed: () => seed(punctuationExemptByTanach: true),
    act: (bloc) =>
        bloc.add(const TogglePunctuation(false, applyToCommentaries: true)),
    expect: () => [
      isA<TextBookLoaded>()
          .having((s) => s.removePunctuation, 'הספר', isFalse)
          .having((s) => s.punctuationExemptByTanach, 'הפטור', isTrue)
          .having(
            (s) => s.commentaryRemovePunctuationOverride,
            'עקיפת המפרשים',
            isFalse,
          )
          .having((s) => s.commentaryRemovePunctuation, 'המפרשים', isFalse),
    ],
  );

  blocTest<TextBookBloc, TextBookState>(
    'TogglePunctuation(true) עם applyToCommentaries מסתיר פיסוק במפרשים בלבד',
    build: () => bloc,
    seed: () => seed(punctuationExemptByTanach: true),
    act: (bloc) =>
        bloc.add(const TogglePunctuation(true, applyToCommentaries: true)),
    expect: () => [
      isA<TextBookLoaded>()
          .having((s) => s.removePunctuation, 'הספר', isFalse)
          .having(
            (s) => s.commentaryRemovePunctuationOverride,
            'עקיפת המפרשים',
            isTrue,
          )
          .having((s) => s.commentaryRemovePunctuation, 'המפרשים', isTrue),
    ],
  );

  blocTest<TextBookBloc, TextBookState>(
    'סגירת כרטיסיית המפרשים מאפסת את העקיפות הזמניות',
    build: () => bloc,
    seed: () =>
        seed(
          nikudExemptByTanach: true,
          punctuationExemptByTanach: true,
        ).copyWith(
          commentaryRemoveNikudOverride: false,
          commentaryRemovePunctuationOverride: false,
        ),
    act: (bloc) => bloc.add(const ResetCommentaryDisplayOverrides()),
    expect: () => [
      isA<TextBookLoaded>()
          .having(
            (s) => s.commentaryRemoveNikudOverride,
            'עקיפת הניקוד',
            isNull,
          )
          .having(
            (s) => s.commentaryRemovePunctuationOverride,
            'עקיפת הפיסוק',
            isNull,
          )
          .having((s) => s.commentaryRemoveNikud, 'המפרשים', isTrue)
          .having((s) => s.commentaryRemovePunctuation, 'המפרשים', isTrue),
    ],
  );
}
