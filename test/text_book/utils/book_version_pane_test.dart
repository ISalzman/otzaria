import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';
import 'package:otzaria/text_book/utils/book_version_pane.dart';

import '../../helpers/memory_settings_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  group('hasVersionsToOpenBeside — מי זכאי לנוסחאות', () {
    test('ספר משתמש נדחה בלי לגשת למאגר', () async {
      final book = TextBook(title: 'ספר אישי', categoryId: 3, isUserBook: true);

      expect(await hasVersionsToOpenBeside(book), isFalse);
    });

    test('ספר בלי categoryId נדחה — המהדורות מאותרות לפי הקטגוריה', () async {
      expect(await hasVersionsToOpenBeside(TextBook(title: 'ספר')), isFalse);
    });
  });

  group('buildBookVersionPaneTab — הטאב שנפתח בחלונית', () {
    test('נפתח בשורה שהתבקשה, כדי שהנוסחים יוצגו באותו קטע', () {
      final versionBook = TextBook(
        title: 'כתובות',
        categoryId: 5,
      ).copyWith(versionTitle: 'Davidson');

      final tab = buildBookVersionPaneTab(
        versionBook: versionBook,
        lineIndex: 412,
      );
      addTearDown(tab.dispose);

      expect(tab.index, 412);
      expect(tab.book.versionTitle, 'Davidson');
    });

    test('נפתח בלי מפרשים ובלי מפרשים בצד', () {
      final tab = buildBookVersionPaneTab(
        versionBook: TextBook(title: 'כתובות', categoryId: 5),
        lineIndex: 0,
      );
      addTearDown(tab.dispose);

      expect(tab.commentators, isEmpty);
      expect((tab.bloc.state as TextBookInitial).splitedView, isFalse);
    });

    test('גם כשברירת המחדל הגלובלית היא מפרשים בצד, החלונית נפתחת בלעדיהם', () {
      Settings.setValue<bool>('key-splited-view', true);
      addTearDown(() => Settings.setValue<bool>('key-splited-view', true));

      final tab = buildBookVersionPaneTab(
        versionBook: TextBook(title: 'כתובות', categoryId: 5),
        lineIndex: 0,
      );
      addTearDown(tab.dispose);

      expect((tab.bloc.state as TextBookInitial).splitedView, isFalse);
    });

    test('כותרת הכרטיסייה נושאת את שם המהדורה בעברית', () {
      final versionBook = TextBook(title: 'כתובות', categoryId: 5).copyWith(
        versionTitle: 'William Davidson Edition - Aramaic',
        heVersionTitle: 'מהדורת דיווידסון',
      );

      final tab = buildBookVersionPaneTab(
        versionBook: versionBook,
        lineIndex: 0,
      );
      addTearDown(tab.dispose);

      expect(tab.title, 'כתובות (מהדורת דיווידסון)');
    });
  });
}
