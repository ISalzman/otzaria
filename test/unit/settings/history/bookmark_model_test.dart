import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';

void main() {
  test('Bookmark.fromJson handles missing commentators field', () {
    final json = {
      'ref': 'test ref',
      'index': 1,
      'book': {'title': 'Book A', 'type': 'TextBook'}
    };
    final bookmark = Bookmark.fromJson(json);
    expect(bookmark.commentatorsToShow, isEmpty);
  });

  test('Bookmark preserves search scope facets in json roundtrip', () {
    final bookmark = Bookmark(
      ref: 'query',
      index: 0,
      book: Bookmark.fromJson({
        'ref': 'inner',
        'index': 1,
        'book': {'title': 'Book A', 'type': 'TextBook'}
      }).book,
      isSearch: true,
      searchScopeFacets: const ['/root/a', '/root/b'],
    );

    final json = bookmark.toJson();
    final restored = Bookmark.fromJson(json);

    expect(restored.searchScopeFacets, ['/root/a', '/root/b']);
  });

  test('Bookmark preserves search mode and typo tolerance in json roundtrip',
      () {
    final bookmark = Bookmark(
      ref: 'query',
      index: 0,
      book: Bookmark.fromJson({
        'ref': 'inner',
        'index': 1,
        'book': {'title': 'Book A', 'type': 'TextBook'}
      }).book,
      isSearch: true,
      searchMode: SearchMode.fuzzy,
      typoToleranceEnabled: true,
    );

    final json = bookmark.toJson();
    final restored = Bookmark.fromJson(json);

    expect(restored.searchMode, SearchMode.fuzzy);
    expect(restored.typoToleranceEnabled, isTrue);
  });
}
