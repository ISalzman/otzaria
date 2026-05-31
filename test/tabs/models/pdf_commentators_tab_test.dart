import 'package:flutter/widgets.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/tabs/models/pdf_commentators_tab.dart';
import 'package:otzaria/tabs/models/pdf_tab.dart';

import '../../helpers/memory_settings_cache.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemorySettingsCache());
  });

  group('PdfCommentatorsTab', () {
    test('title נגזר מה-sourceTab', () {
      final sourceTab = PdfBookTab(
        book: PdfBook(title: 'PDF בדיקה', path: '/tmp/book.pdf'),
        pageNumber: 5,
      );
      addTearDown(sourceTab.dispose);

      final tab = PdfCommentatorsTab(sourceTab: sourceTab);

      expect(tab.title, 'מפרשים | PDF בדיקה');
      expect(tab.sourceTab, same(sourceTab));
    });

    test('toJson שומר את הסוג, pinned, sourceTab והמפרשים הפעילים', () {
      final sourceTab = PdfBookTab(
        book: PdfBook(title: 'PDF בדיקה', path: '/tmp/book.pdf'),
        pageNumber: 5,
      );
      sourceTab.activeCommentators.add('רש"י');
      addTearDown(sourceTab.dispose);

      final tab = PdfCommentatorsTab(sourceTab: sourceTab)..isPinned = true;
      final json = tab.toJson();

      expect(json['title'], 'מפרשים | PDF בדיקה');
      expect(json['type'], 'PdfCommentatorsTab');
      expect(json['isPinned'], true);
      expect(json['activeCommentators'], ['רש"י']);
      expect(json['sourceTab'], isA<Map>());
      expect((json['sourceTab'] as Map)['path'], '/tmp/book.pdf');
      expect((json['sourceTab'] as Map)['pageNumber'], 5);
    });

    test('fromJson משחזר את ה-sourceTab, העמוד והמפרשים הפעילים', () {
      final sourceTab = PdfBookTab(
        book: PdfBook(title: 'PDF בדיקה', path: '/tmp/book.pdf'),
        pageNumber: 5,
      );
      sourceTab.activeCommentators.addAll({'רש"י', 'תוספות'});
      final tab = PdfCommentatorsTab(sourceTab: sourceTab)..isPinned = true;
      final json = tab.toJson();
      // משחררים את המקור — השחזור חייב לעמוד בפני עצמו
      sourceTab.dispose();

      final restored = PdfCommentatorsTab.fromJson(json);
      addTearDown(restored.dispose);

      expect(restored.title, 'מפרשים | PDF בדיקה');
      expect(restored.isPinned, true);
      expect(restored.sourceTab.book.title, 'PDF בדיקה');
      expect(restored.sourceTab.book.path, '/tmp/book.pdf');
      expect(restored.sourceTab.pageNumber, 5);
      expect(restored.sourceTab.activeCommentators, {'רש"י', 'תוספות'});
    });
  });
}
