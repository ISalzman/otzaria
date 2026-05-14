import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_event.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import '../../helpers/memory_settings_cache.dart';

class _StubTextBookBloc extends Bloc<TextBookEvent, TextBookState>
    implements TextBookBloc {
  _StubTextBookBloc()
      : super(TextBookInitial.named(
          TextBook(title: 'ספר בדיקה'),
          0,
          false,
          const [],
        )) {
    on<TextBookEvent>((_, __) {});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  group('TextBookTab - notifiers של קיצורי מקלדת', () {
    test('toggleCommentatorsPaneNotifier מתחיל ב-0', () {
      final bloc = _StubTextBookBloc();
      final tab = TextBookTab(
        book: TextBook(title: 'ספר בדיקה'),
        index: 0,
        blocOverride: bloc,
      );
      addTearDown(tab.dispose);

      expect(tab.toggleCommentatorsPaneNotifier.value, 0);
    });

    test('הגדלת toggleCommentatorsPaneNotifier משדרת ל-listener', () {
      final bloc = _StubTextBookBloc();
      final tab = TextBookTab(
        book: TextBook(title: 'ספר בדיקה'),
        index: 0,
        blocOverride: bloc,
      );
      addTearDown(tab.dispose);

      var calls = 0;
      void listener() => calls++;
      tab.toggleCommentatorsPaneNotifier.addListener(listener);
      addTearDown(
          () => tab.toggleCommentatorsPaneNotifier.removeListener(listener));

      tab.toggleCommentatorsPaneNotifier.value++;
      tab.toggleCommentatorsPaneNotifier.value++;

      expect(calls, 2);
      expect(tab.toggleCommentatorsPaneNotifier.value, 2);
    });
  });
}
