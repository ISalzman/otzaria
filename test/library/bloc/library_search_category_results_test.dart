import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/models/books.dart';

Category _cat(String title) => Category(
  title: title,
  description: '',
  shortDescription: '',
  order: 0,
  subCategories: [],
  books: [],
  parent: null,
);

void main() {
  group('תוצאות קטגוריות בחיפוש הספרייה (issue #956)', () {
    test('copyWith בלי ערך מאפס את תוצאות הקטגוריות, כמו את תוצאות הספרים', () {
      final withResults = const LibraryState().copyWith(
        searchResults: const <Book>[],
        searchCategoryResults: [_cat('שבת')],
      );
      expect(withResults.searchCategoryResults, hasLength(1));

      // ה-copyWith של _onNavigateToCategory — שני סוגי התוצאות מתאפסים יחד.
      final navigated = withResults.copyWith(
        searchQuery: null,
        searchResults: null,
        selectedTopics: null,
      );
      expect(navigated.searchResults, isNull);
      expect(navigated.searchCategoryResults, isNull);
    });

    test('שימור מפורש מעביר את שתי הרשימות', () {
      final withResults = const LibraryState().copyWith(
        searchResults: const <Book>[],
        searchCategoryResults: [_cat('שבת')],
      );
      final preserved = withResults.copyWith(
        isSearching: true,
        searchResults: withResults.searchResults,
        searchCategoryResults: withResults.searchCategoryResults,
      );
      expect(preserved.searchResults, isNotNull);
      expect(preserved.searchCategoryResults, hasLength(1));
    });
  });
}
