import 'package:flutter_test/flutter_test.dart';
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
}
