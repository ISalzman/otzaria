import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/data/repository/hive_list_repository.dart';

class BookmarkRepository {
  final HiveListRepository<Bookmark> _repo = HiveListRepository<Bookmark>(
    boxName: 'bookmarks',
    key: 'key-bookmarks',
    fromJson: (json) => Bookmark.fromJson(json),
    toJson: (bookmark) => bookmark.toJson(),
  );

  Future<List<Bookmark>> loadBookmarks() async {
    return await _repo.load();
  }

  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {
    await _repo.save(bookmarks);
  }

  Future<void> clearBookmarks() async {
    await _repo.clear();
  }
}
