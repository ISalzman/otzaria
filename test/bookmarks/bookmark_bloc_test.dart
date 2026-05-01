import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_bloc.dart';
import 'package:otzaria/bookmarks/bloc/bookmark_state.dart';
import 'package:otzaria/bookmarks/models/bookmark.dart';
import 'package:otzaria/bookmarks/repository/bookmark_repository.dart';
import 'package:otzaria/models/books.dart';

// ─── Fake repository ─────────────────────────────────────────────────────────

class _FakeBookmarkRepository implements BookmarkRepository {
  List<Bookmark> _bookmarks;
  int saveCallCount = 0;
  int clearCallCount = 0;

  _FakeBookmarkRepository({List<Bookmark>? initial})
      : _bookmarks = initial ?? [];

  @override
  Future<List<Bookmark>> loadBookmarks() async => List.from(_bookmarks);

  @override
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {
    _bookmarks = List.from(bookmarks);
    saveCallCount++;
  }

  @override
  Future<void> clearBookmarks() async {
    _bookmarks = [];
    clearCallCount++;
  }

  // Unused BaseListRepository methods
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

TextBook _book({String title = 'ספר א'}) => TextBook(
      title: title,
      filePath: '/fake/$title.txt',
    );

Bookmark _bookmark({
  String ref = 'בראשית א',
  String bookTitle = 'ספר א',
  int index = 0,
}) =>
    Bookmark(ref: ref, book: _book(title: bookTitle), index: index);

Future<BookmarkBloc> _makeBloc({List<Bookmark>? initial}) async {
  final repo = _FakeBookmarkRepository(initial: initial);
  final bloc = BookmarkBloc(repo);
  // Allow _loadBookmarks to complete
  await Future<void>.delayed(Duration.zero);
  return bloc;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('BookmarkBloc', () {
    group('initial load', () {
      test('מתחיל עם רשימה ריקה כאשר אין סימניות', () async {
        final bloc = await _makeBloc();
        expect(bloc.state.bookmarks, isEmpty);
      });

      test('טוען סימניות קיימות ב-init', () async {
        final existing = [_bookmark(ref: 'בראשית א'), _bookmark(ref: 'שמות א')];
        final bloc = await _makeBloc(initial: existing);
        expect(bloc.state.bookmarks.length, 2);
        expect(bloc.state.bookmarks[0].ref, 'בראשית א');
        expect(bloc.state.bookmarks[1].ref, 'שמות א');
      });
    });

    group('addBookmark', () {
      test('מוסיף סימנייה חדשה ומחזיר true', () async {
        final bloc = await _makeBloc();
        final result = bloc.addBookmark(
          ref: 'בראשית א',
          book: _book(),
          index: 0,
        );
        expect(result, isTrue);
        expect(bloc.state.bookmarks.length, 1);
        expect(bloc.state.bookmarks.first.ref, 'בראשית א');
      });

      test('לא מוסיף סימנייה כפולה ומחזיר false', () async {
        final bloc = await _makeBloc(initial: [_bookmark(ref: 'בראשית א')]);
        final result = bloc.addBookmark(
          ref: 'בראשית א',
          book: _book(),
          index: 0,
        );
        expect(result, isFalse);
        expect(bloc.state.bookmarks.length, 1);
      });

      test('שומר את הסימנייה ב-repository', () async {
        final repo = _FakeBookmarkRepository();
        final bloc = BookmarkBloc(repo);
        await Future<void>.delayed(Duration.zero);

        bloc.addBookmark(ref: 'בראשית א', book: _book(), index: 0);

        expect(repo.saveCallCount, 1);
        expect(repo._bookmarks.length, 1);
      });

      test('שומר commentatorsToShow בסימנייה', () async {
        final bloc = await _makeBloc();
        bloc.addBookmark(
          ref: 'בראשית א',
          book: _book(),
          index: 0,
          commentatorsToShow: ['רש"י', 'רמב"ן'],
        );
        expect(bloc.state.bookmarks.first.commentatorsToShow,
            ['רש"י', 'רמב"ן']);
      });

      test('מוסיף מספר סימניות שונות', () async {
        final bloc = await _makeBloc();
        bloc.addBookmark(ref: 'בראשית א', book: _book(), index: 0);
        bloc.addBookmark(ref: 'שמות א', book: _book(title: 'ספר ב'), index: 5);
        expect(bloc.state.bookmarks.length, 2);
      });
    });

    group('removeBookmark', () {
      test('מסיר סימנייה לפי אינדקס', () async {
        final bloc = await _makeBloc(initial: [
          _bookmark(ref: 'בראשית א'),
          _bookmark(ref: 'שמות א'),
        ]);
        bloc.removeBookmark(0);
        expect(bloc.state.bookmarks.length, 1);
        expect(bloc.state.bookmarks.first.ref, 'שמות א');
      });

      test('שומר אחרי הסרה', () async {
        final repo = _FakeBookmarkRepository(
            initial: [_bookmark(ref: 'בראשית א')]);
        final bloc = BookmarkBloc(repo);
        await Future<void>.delayed(Duration.zero);

        bloc.removeBookmark(0);

        expect(repo.saveCallCount, 1);
        expect(repo._bookmarks, isEmpty);
      });

      test('מסיר מהסוף ללא השפעה על שאר הסימניות', () async {
        final bloc = await _makeBloc(initial: [
          _bookmark(ref: 'א'),
          _bookmark(ref: 'ב'),
          _bookmark(ref: 'ג'),
        ]);
        bloc.removeBookmark(2);
        expect(bloc.state.bookmarks.map((b) => b.ref).toList(), ['א', 'ב']);
      });
    });

    group('clearBookmarks', () {
      test('מנקה את כל הסימניות', () async {
        final bloc = await _makeBloc(initial: [
          _bookmark(ref: 'בראשית א'),
          _bookmark(ref: 'שמות א'),
        ]);
        bloc.clearBookmarks();
        expect(bloc.state.bookmarks, isEmpty);
      });

      test('קורא ל-clearBookmarks ב-repository', () async {
        final repo = _FakeBookmarkRepository(
            initial: [_bookmark(ref: 'בראשית א')]);
        final bloc = BookmarkBloc(repo);
        await Future<void>.delayed(Duration.zero);

        bloc.clearBookmarks();

        expect(repo.clearCallCount, 1);
      });
    });

    group('BookmarkState', () {
      test('copyWith מעדכן רק את השדות שנמסרו', () {
        final state = BookmarkState(bookmarks: [_bookmark()]);
        final updated = state.copyWith(bookmarks: []);
        expect(updated.bookmarks, isEmpty);
      });

      test('copyWith ללא ארגומנטים מחזיר אותו ערך', () {
        final bookmarks = [_bookmark()];
        final state = BookmarkState(bookmarks: bookmarks);
        final copy = state.copyWith();
        expect(copy.bookmarks, same(bookmarks));
      });

      test('BookmarkState.initial מחזיר רשימה ריקה', () {
        final state = BookmarkState.initial();
        expect(state.bookmarks, isEmpty);
      });
    });
  });

  group('Bookmark model', () {
    test('toJson ו-fromJson עוברים סיבוב מלא', () {
      final original = Bookmark(
        ref: 'בראשית א א',
        book: _book(title: 'בראשית'),
        index: 42,
        commentatorsToShow: ['רש"י'],
      );

      final json = original.toJson();
      final restored = Bookmark.fromJson(json);

      expect(restored.ref, original.ref);
      expect(restored.book.title, original.book.title);
      expect(restored.index, original.index);
      expect(restored.commentatorsToShow, original.commentatorsToShow);
    });

    test('historyKey הוא כותרת הספר לסימנייה רגילה', () {
      final bm = _bookmark(bookTitle: 'בראשית');
      expect(bm.historyKey, 'בראשית');
    });

    test('historyKey הוא ref לסימנייה חיפוש', () {
      final bm = Bookmark(
        ref: 'שאילתא',
        book: _book(),
        index: 0,
        isSearch: true,
      );
      expect(bm.historyKey, 'שאילתא');
    });

    test('fromJson מטפל ב-commentatorsToShow חסר', () {
      final json = {
        'ref': 'א',
        'index': 0,
        'book': _book().toJson(),
      };
      final bm = Bookmark.fromJson(json);
      expect(bm.commentatorsToShow, isEmpty);
    });

    test('fromJson מטפל ב-isSearch חסר (ברירת מחדל false)', () {
      final json = {
        'ref': 'א',
        'index': 0,
        'book': _book().toJson(),
      };
      final bm = Bookmark.fromJson(json);
      expect(bm.isSearch, isFalse);
    });
  });
}
