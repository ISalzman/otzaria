import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/history/bloc/history_bloc.dart';
import 'package:otzaria/history/bloc/history_event.dart';
import 'package:otzaria/history/bloc/history_state.dart';
import 'package:otzaria/history/history_repository.dart';
import 'package:otzaria/models/books.dart';

class _BlockingHistoryRepository extends HistoryRepository {
  final loadStarted = Completer<void>();
  final releaseLoad = Completer<List<Bookmark>>();
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  int saveCount = 0;

  @override
  Future<List<Bookmark>> load() {
    loadStarted.complete();
    return releaseLoad.future;
  }

  /// מה ש"על הדיסק". [mutate] האמיתי קורא אותו מחדש לפני כל החלה, וזה מה
  /// שהופך שתי כתיבות רצופות לצטברות במקום לדרוס.
  List<Bookmark> stored = [];

  @override
  Future<List<Bookmark>> mutate(
    List<Bookmark> Function(List<Bookmark> current) apply,
  ) async {
    saveCount++;
    if (saveCount == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    stored = List<Bookmark>.from(apply(List<Bookmark>.from(stored)));
    return List<Bookmark>.from(stored);
  }
}

Bookmark _bookmark(String title) => Bookmark(
  ref: title,
  book: TextBook(title: title),
  index: 0,
);

void main() {
  test('כתיבות היסטוריה רצופות נשמרות בלי לדרוס זו את זו', () async {
    final repository = _BlockingHistoryRepository();
    final bloc = HistoryBloc(repository);
    addTearDown(bloc.close);

    await repository.loadStarted.future;
    final loaded = bloc.stream.firstWhere((state) => state is HistoryLoaded);
    repository.releaseLoad.complete([]);
    await loaded;

    final first = _bookmark('ספר א');
    final second = _bookmark('ספר ב');
    bloc.add(BulkAddHistory([first]));
    await repository.firstSaveStarted.future;

    bloc.add(BulkAddHistory([second]));
    await Future<void>.delayed(Duration.zero);
    expect(repository.saveCount, 1);

    repository.releaseFirstSave.complete();
    await bloc.stream.firstWhere((state) => state.history.length == 2);

    expect(bloc.state.history.map((bookmark) => bookmark.book.title), [
      'ספר ב',
      'ספר א',
    ]);
  });
}
