import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/data/repository/hive_list_repository.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';
import 'package:otzaria/tabs/models/tab.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/utils/ref_helper.dart';

class HistoryRepository {
  final HiveListRepository<Bookmark> _repo = HiveListRepository<Bookmark>(
    boxName: 'history',
    key: 'history',
    fromJson: (json) => Bookmark.fromJson(json),
    toJson: (bookmark) => bookmark.toJson(),
  );

  Future<List<Bookmark>> loadHistory() async {
    return await _repo.load();
  }

  Future<void> saveHistory(List<Bookmark> history) async {
    await _repo.save(history);
  }

  Future<void> clearHistory() async {
    await _repo.clear();
  }

  Future<void> addHistoryItem(Bookmark bookmark) async {
    await _repo.addItem(bookmark);
  }

  Future<void> addHistoryFromTab(OpenedTab tab) async {
    if (tab is PdfBookTab) {
      int index = tab.pdfViewerController.pageNumber ?? 1;
      addHistoryItem(Bookmark(
        ref: '${tab.title} עמוד $index',
        book: tab.book,
        index: index,
      ));
    }
    if (tab is TextBookTab) {
      final state = tab.bloc.state;
      if (state is TextBookLoaded) {
        final index = state.positionsListener.itemPositions.value.first.index;
        addHistoryItem(Bookmark(
          ref: await refFromIndex(index, tab.book.tableOfContents),
          book: tab.book,
          index: index,
        ));
      }
    }
  }

  Future<void> removeHistoryItem(int index) async {
    await _repo.removeAt(index);
  }
}
