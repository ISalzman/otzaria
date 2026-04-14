import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/data/data_providers/tantivy_data_provider.dart';

void main() {
  group('TantivyDataProvider.shouldInvalidateStoredIndexState', () {
    test('מחזיר true כשגרסת מצב האינדקס השתנתה', () {
      final shouldInvalidate =
          TantivyDataProvider.shouldInvalidateStoredIndexState(
        storedIndexStateVersion:
            TantivyDataProvider.currentIndexStateVersion - 1,
        storedCatalogueOrderSignature: 'same-signature',
        currentCatalogueOrderSignature: 'same-signature',
      );

      expect(shouldInvalidate, isTrue);
    });

    test('מחזיר true כשחתימת הקטלוג השתנתה', () {
      final shouldInvalidate =
          TantivyDataProvider.shouldInvalidateStoredIndexState(
        storedIndexStateVersion: TantivyDataProvider.currentIndexStateVersion,
        storedCatalogueOrderSignature: 'old-signature',
        currentCatalogueOrderSignature: 'new-signature',
      );

      expect(shouldInvalidate, isTrue);
    });

    test('מחזיר false כשהגרסה והחתימה תואמות', () {
      final shouldInvalidate =
          TantivyDataProvider.shouldInvalidateStoredIndexState(
        storedIndexStateVersion: TantivyDataProvider.currentIndexStateVersion,
        storedCatalogueOrderSignature: 'same-signature',
        currentCatalogueOrderSignature: 'same-signature',
      );

      expect(shouldInvalidate, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Migration tests
  //
  // NOTE: TantivyDataProvider is a singleton that initialises asynchronously.
  // In this test environment platform-channel calls (path_provider) fail, so
  // the singleton's _loadBooksDone() catch-block fires and no 'books_indexed'
  // Hive box is ever opened by the singleton.  The migration tests therefore
  // have exclusive access to Hive and can open/close boxes freely.
  // ---------------------------------------------------------------------------
  group('TantivyDataProvider.migrateBooksDone', () {
    late Directory tempDir;
    late String legacyDir;
    late String currentDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('otzaria_migration_test_');
      legacyDir = '${tempDir.path}/legacy';
      currentDir = '${tempDir.path}/current';
      Directory(legacyDir).createSync();
      Directory(currentDir).createSync();
    });

    tearDown(() async {
      await Hive.close();
      tempDir.deleteSync(recursive: true);
    });

    test('מגרת רשימת ספרים מנתיב legacy לנתיב חדש', () async {
      // Arrange: write legacy data.
      final legacyBox =
          await Hive.openBox<dynamic>('books_indexed', path: legacyDir);
      await legacyBox.put('key-books-done', ['book1.txt', 'book2.txt']);
      await legacyBox.close();

      // Act.
      final migrated = await TantivyDataProvider.migrateBooksDone(
        currentDir: currentDir,
        legacyDir: legacyDir,
      );

      // Assert: returned list matches what was in legacy.
      expect(migrated, containsAll(['book1.txt', 'book2.txt']));
      expect(migrated, hasLength(2));

      // Assert: new path box contains the data.
      final newBox =
          await Hive.openBox<dynamic>('books_indexed', path: currentDir);
      final books = (newBox.get('key-books-done', defaultValue: <dynamic>[])
              as List)
          .map<String>((e) => e.toString())
          .toList();
      await newBox.close();
      expect(books, containsAll(['book1.txt', 'book2.txt']));

      // Assert: legacy .hive file has been removed.
      expect(File('$legacyDir/books_indexed.hive').existsSync(), isFalse);
    });

    test('לא מגרת כאשר ה-legacy ריק', () async {
      // Arrange: empty box at legacy path.
      final legacyBox =
          await Hive.openBox<dynamic>('books_indexed', path: legacyDir);
      await legacyBox.close();

      // Act.
      final migrated = await TantivyDataProvider.migrateBooksDone(
        currentDir: currentDir,
        legacyDir: legacyDir,
      );

      expect(migrated, isEmpty);

      // The current directory should remain untouched.
      expect(File('$currentDir/books_indexed.hive').existsSync(), isFalse);
    });

    test('לא מגרת כאשר נתיב ה-legacy אינו קיים', () async {
      final migrated = await TantivyDataProvider.migrateBooksDone(
        currentDir: currentDir,
        legacyDir: '${tempDir.path}/nonexistent',
      );

      expect(migrated, isEmpty);
    });

    test('לא מגרת כאשר הנתיב הישן זהה לנתיב החדש', () async {
      // Arrange: put data at the path so we can confirm nothing is read.
      final box =
          await Hive.openBox<dynamic>('books_indexed', path: currentDir);
      await box.put('key-books-done', ['book.txt']);
      await box.close();

      final migrated = await TantivyDataProvider.migrateBooksDone(
        currentDir: currentDir,
        legacyDir: currentDir, // same path
      );

      // Must short-circuit immediately — no data returned.
      expect(migrated, isEmpty);
    });
  });
}
