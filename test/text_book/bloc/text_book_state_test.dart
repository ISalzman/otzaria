import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  group('TextBookLoaded equality', () {
    test('changes when spacing values change', () {
      final withSpacing = _loadedState(
        spacingValues: const {'0-1': '1'},
      );
      final withoutSpacing = _loadedState();

      expect(withSpacing, isNot(equals(withoutSpacing)));
    });

    test('changes when advanced search options change', () {
      final withOptions = _loadedState(
        searchOptions: const {
          'אמר_0': {'סיומות': true},
        },
      );
      final withoutOptions = _loadedState();

      expect(withOptions, isNot(equals(withoutOptions)));
    });

    test('changes when search mode changes', () {
      final advanced = _loadedState(searchMode: SearchMode.advanced);
      final exact = _loadedState();

      expect(advanced, isNot(equals(exact)));
    });

    test('changes when typo tolerance changes', () {
      final withTypoTolerance = _loadedState(typoToleranceEnabled: true);
      final withoutTypoTolerance = _loadedState();

      expect(withTypoTolerance, isNot(equals(withoutTypoTolerance)));
    });
  });
}

TextBookLoaded _loadedState({
  Map<String, Map<String, bool>> searchOptions = const {},
  Map<int, List<String>> alternativeWords = const {},
  Map<String, String> spacingValues = const {},
  SearchMode searchMode = SearchMode.exact,
  bool typoToleranceEnabled = false,
}) {
  return TextBookLoaded(
    book: TextBook(title: 'ספר בדיקה'),
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
    visibleIndices: const [0],
    pinLeftPane: false,
    searchText: 'אמר רבי',
    searchOptions: searchOptions,
    alternativeWords: alternativeWords,
    spacingValues: spacingValues,
    searchMode: searchMode,
    typoToleranceEnabled: typoToleranceEnabled,
    scrollController: ItemScrollController(),
    positionsListener: ItemPositionsListener.create(),
  );
}
