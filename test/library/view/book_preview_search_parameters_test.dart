import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/models/library.dart';
import 'package:otzaria/library/view/book_preview_panel.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/search/models/search_configuration.dart';
import 'package:otzaria_search_engine/otzaria_search_engine.dart'
    show SearchScope;

import '../../helpers/memory_settings_cache.dart';

TextBook _book() => TextBook(
  title: 'ברכות',
  category: Category(
    title: 'סדר זרעים',
    description: '',
    shortDescription: '',
    order: 0,
    subCategories: [],
    books: [],
    parent: null,
  ),
  categoryId: 10,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  group('טאב התצוגה המקדימה — פרמטרי חיפוש (issue #1147)', () {
    test('שאילתה פשוטה מגיעה לטאב', () {
      final tab = buildPreviewTextTab(
        book: _book(),
        targetIndex: 7,
        searchText: 'אבל',
      );

      expect(tab.searchText, 'אבל');
      expect(tab.index, 7);
    });

    test('אפשרויות החיפוש המתקדמות מגיעות לטאב', () {
      final tab = buildPreviewTextTab(
        book: _book(),
        targetIndex: 7,
        searchText: 'אבל',
        searchOptions: const {
          'אבל': {'prefixes': true},
        },
        alternativeWords: const {
          0: ['ברם'],
        },
        spacingValues: const {'0': '2'},
        searchMode: SearchMode.fuzzy,
        searchDistance: 3,
        matchPolicy: const SearchMatchPolicy(
          proximityScope: SearchScope.sameParagraph,
        ),
      );

      expect(tab.searchOptions, {
        'אבל': {'prefixes': true},
      });
      expect(tab.alternativeWords, {
        0: ['ברם'],
      });
      expect(tab.spacingValues, {'0': '2'});
      expect(tab.searchMode, SearchMode.fuzzy);
      expect(tab.searchDistance, 3);
      expect(tab.matchPolicy.proximityScope, SearchScope.sameParagraph);
    });

    test('תצוגה מקדימה ללא תוצאה נבחרת אינה נושאת חיפוש', () {
      final tab = buildPreviewTextTab(
        book: _book(),
        targetIndex: null,
        searchText: 'אבל',
        searchOptions: const {
          'אבל': {'prefixes': true},
        },
        searchDistance: 3,
      );

      expect(tab.searchText, isEmpty);
      expect(tab.searchOptions, isEmpty);
      expect(tab.searchDistance, 0);
      expect(tab.initialSearchResultLines, isNull);
    });
  });
}
