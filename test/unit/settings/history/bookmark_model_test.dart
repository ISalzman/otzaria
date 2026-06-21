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

  test('Bookmark preserves label in json roundtrip', () {
    final bookmark = Bookmark(
      ref: 'בראשית א',
      index: 0,
      book: Bookmark.fromJson({
        'ref': 'inner',
        'index': 1,
        'book': {'title': 'Book A', 'type': 'TextBook'}
      }).book,
      label: 'בראשית ברא אלהים את',
    );

    final restored = Bookmark.fromJson(bookmark.toJson());

    expect(restored.label, 'בראשית ברא אלהים את');
  });

  test('Bookmark.copyWith with clearLabel resets label to null', () {
    final bookmark = Bookmark(
      ref: 'בראשית א',
      index: 0,
      book: Bookmark.fromJson({
        'ref': 'inner',
        'index': 1,
        'book': {'title': 'Book A', 'type': 'TextBook'}
      }).book,
      label: 'תיאור',
    );

    expect(bookmark.copyWith(label: 'חדש').label, 'חדש');
    expect(bookmark.copyWith(clearLabel: true).label, isNull);
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

  test('Bookmark preserves search mode in json roundtrip', () {
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
    );

    final json = bookmark.toJson();
    final restored = Bookmark.fromJson(json);

    expect(restored.searchMode, SearchMode.fuzzy);
  });
}
