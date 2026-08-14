import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/utils/book_versions_action.dart';

import '../../helpers/memory_settings_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  group('hasBookVersionsToOpen — מי זכאי לנוסחאות', () {
    test('ספר משתמש נדחה בלי לגשת למאגר', () async {
      final book = TextBook(title: 'ספר אישי', categoryId: 3, isUserBook: true);

      expect(await hasBookVersionsToOpen(book), isFalse);
    });

    test('ספר בלי categoryId נדחה — המהדורות מאותרות לפי הקטגוריה', () async {
      expect(await hasBookVersionsToOpen(TextBook(title: 'ספר')), isFalse);
    });
  });

  group('כותרת הכרטיסייה של נוסח', () {
    test('נושאת את שם המהדורה בעברית, ולא את מפתח ה-DB האנגלי', () {
      final versionBook = TextBook(title: 'כתובות', categoryId: 5).copyWith(
        versionTitle: 'William Davidson Edition - Aramaic',
        heVersionTitle: 'מהדורת דיווידסון',
      );

      final tab = TextBookTab(book: versionBook, index: 0);
      addTearDown(tab.dispose);

      expect(tab.title, 'כתובות (מהדורת דיווידסון)');
    });
  });
}
