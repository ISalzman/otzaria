import 'package:otzaria/bookmarks/models/bookmark.dart';

class BookmarkState {
  final List<Bookmark> bookmarks;

  BookmarkState({required this.bookmarks});

  factory BookmarkState.initial() {
    return BookmarkState(bookmarks: const []);
  }

  BookmarkState copyWith({List<Bookmark>? bookmarks}) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
    );
  }
}
